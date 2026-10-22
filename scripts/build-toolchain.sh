#!/usr/bin/env bash
# build-toolchain.sh — build one host toolchain (native compiler + cross compilers + units) and package it.
#
#   scripts/build-toolchain.sh --src DIR --work DIR --bootstrap PPC --build N [options] STEP...
#
# Steps (run in order given; each is restartable):
#   native        stamp the build identity, `make all` with the bootstrap compiler, `make install` into
#                 WORK/stage (Unix layout: bin/, lib/fpc/<ver>/, share/)
#   cross         for every cross target selected (--targets): `make crossall` + `make crossinstall`
#                 with the staged native compiler; per-target logs and WORK/cross-status.tsv
#   compilers     cross COMPILERS only (no units) for every CPU of the selected targets, built in the
#                 native tree: for hosts that use the canonical unit archives of another build
#   canadian      build toolchains that RUN on another host (--canadian x86_64-win64[,aarch64-win64])
#                 from the staged compilers: compiler + RTL/packages/utils for that host + its cross compilers
#   finish        relative bin/ links, share/fpc-toolchain/{BUILDINFO,targets.tsv,...}
#   package       WORK/dist/fpc-<identity>-<host>.tar.xz (native toolchain + all cross compilers + host units;
#                 .zip for Windows hosts) and, with --unit-archives, fpc-<identity>-units-<target>.tar.xz
#                 for every cross target (units do not depend on the host; the installer adds the targets
#                 a machine wants)
#
# Options:
#   --src DIR          prepared source tree (scripts/fetch-source.sh); never modified
#   --work DIR         scratch + output dir
#   --bootstrap PPC    bootstrap compiler (FPC 3.2.2 ppcx64/ppca64), needed by `native`
#   --build N          build number; identity = FPC_VERSION FPC_UPSTREAM_MINORPATCH + "+N"
#   --targets SPEC     cross targets: "host" (targets.tsv rows whose hosts column matches this host;
#                      default), "all" (every row not marked excluded), or a comma list of targets
#   --canadian LIST    comma list of other hosts for the `canadian` step
#   --jobs N           make -j (default: CPU count, max 8)
#   --lanes N          concurrent cross builds (default 1); each lane uses its own copy of the source
#   --toolpath DIR     prepended to PATH (cross binutils, clang shims)
#   --keep-going       record failing cross targets and continue (default: stop at first failure)
#   --memcap SIZE      wrap each make in `systemd-run --user --scope -p MemoryMax=SIZE` (Linux only)
#   --unit-archives    package: also write one units archive per cross target (canonical build only)
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=/dev/null
. "$here/toolchain.conf"

src='' work='' bootstrap='' build='' targets_spec=host canadian='' jobs='' lanes=1 toolpath='' keepgoing=0 memcap='' unitarchives=0
steps=()
while [ $# -gt 0 ]; do
  case $1 in
    --src) src=$2; shift 2 ;;
    --work) work=$2; shift 2 ;;
    --bootstrap) bootstrap=$2; shift 2 ;;
    --build) build=$2; shift 2 ;;
    --targets) targets_spec=$2; shift 2 ;;
    --canadian) canadian=$2; shift 2 ;;
    --jobs) jobs=$2; shift 2 ;;
    --lanes) lanes=$2; shift 2 ;;
    --toolpath) toolpath=$2; shift 2 ;;
    --keep-going) keepgoing=1; shift ;;
    --memcap) memcap=$2; shift 2 ;;
    --unit-archives) unitarchives=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    -*) echo "unknown option $1" >&2; exit 2 ;;
    *) steps+=("$1"); shift ;;
  esac
done
[ -n "$src" ] && [ -n "$work" ] && [ -n "$build" ] || { echo "need --src --work --build" >&2; exit 2; }
[ ${#steps[@]} -gt 0 ] || steps=(native cross finish package)
src=$(cd "$src" && pwd)
mkdir -p "$work"; work=$(cd "$work" && pwd)
[ -n "$toolpath" ] && export PATH="$toolpath:$PATH"

ncpu=$( (nproc || sysctl -n hw.ncpu) 2>/dev/null || echo 4)
[ -n "$jobs" ] || { jobs=$ncpu; [ "$jobs" -gt 8 ] && jobs=8; }

identity="${FPC_VERSION}${FPC_UPSTREAM_MINORPATCH}+${build}"
# release tag / asset id: the identity with "+N" written "-bN" (no URL escaping): 3.2.4-rc2+1 -> 3.2.4-rc2-b1
tag="${FPC_VERSION}${FPC_UPSTREAM_MINORPATCH}-b${build}"
asset_id="fpc-${tag}"
stage=$work/stage
logs=$work/logs
mkdir -p "$logs"

case $(uname -s) in Linux) host_os=linux ;; Darwin) host_os=darwin ;; *) echo "unsupported build host" >&2; exit 1 ;; esac
case $(uname -m) in x86_64|amd64) host_cpu=x86_64 ;; aarch64|arm64) host_cpu=aarch64 ;; *) echo "unsupported cpu" >&2; exit 1 ;; esac
host=$host_cpu-$host_os
case $host_cpu in x86_64) ppcname=ppcx64 ;; aarch64) ppcname=ppca64 ;; esac

log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }

run_make() { # run_make LOGFILE make-args...
  local lf=$1; shift
  if [ -n "$memcap" ] && [ "$host_os" = linux ]; then
    systemd-run --user --scope -q -p MemoryMax="$memcap" -p MemorySwapMax=0 -- make "$@" >>"$lf" 2>&1
  else
    make "$@" >>"$lf" 2>&1
  fi
}

copy_tree() { # copy_tree DEST — fresh copy of the source tree without .git
  rm -rf "$1"; mkdir -p "$1"
  (cd "$src" && tar --exclude=.git -cf - .) | (cd "$1" && tar -xf -)
}

stamp_identity() { # stamp_identity TREE
  local f=$1/compiler/version.pas
  # minorpatch = '<upstream minorpatch>+<build>' -> `fpc -iW` prints the identity
  sed -e "s/^\( *minorpatch *= *\)'[^']*';/\1'${FPC_UPSTREAM_MINORPATCH}+${build}';/" "$f" > "$f.new"
  mv "$f.new" "$f"
  grep -q "minorpatch *= *'${FPC_UPSTREAM_MINORPATCH}+${build}'" "$f" || { echo "identity stamp failed" >&2; exit 1; }
}

# ---- targets table -------------------------------------------------------------------------------
# targets/targets.tsv columns (tab separated, '#' comments):
#   target  class  hosts  binutils  make_args  run  notes
# class: internal | binutils | sdk | excluded ; hosts: comma list of build hosts or '*'
# binutils: prefix of the GNU binutils to use on Linux build hosts ('-' = none/internal,
#           'clang:<triple>' = clang integrated assembler via a shim)
tsv=$here/targets/targets.tsv
target_field() { # target_field TARGET COLUMN(1-based)
  awk -F'\t' -v t="$1" -v c="$2" '$0 !~ /^#/ && $1==t {print $c; exit}' "$tsv"
}
# FPC installs the units of 8.3-filesystem targets (go32v2, msdos, ...) as units/<os>, others as units/<cpu>-<os>
unitdir_target() { # unitdir_target DIR -> target name (UNITDIR= in targets.tsv, else <cpu>-<os> or the 8.3 os name)
  local t; t=$(awk -F'\t' -v d="$1" '$0 !~ /^#/ && (";" $5 ";") ~ (";UNITDIR=" d ";") {print $1; exit}' "$tsv")
  [ -n "$t" ] && { echo "$t"; return; }
  case $1 in *-*) echo "$1" ;; *) awk -F'\t' -v d="$1" '$0 !~ /^#/ && $1 ~ ("-" d "$") {print $1; exit}' "$tsv" ;; esac
}
select_targets() {
  case $targets_spec in
    host) awk -F'\t' -v h="$host" '$0 !~ /^#/ && NF>=3 && $2!="excluded" && $1!=h && ($3=="*" || (","$3",") ~ (","h",")) {print $1}' "$tsv" ;;
    all)  awk -F'\t' -v h="$host" '$0 !~ /^#/ && NF>=3 && $2!="excluded" && $1!=h {print $1}' "$tsv" ;;
    none|'') ;;
    *) echo "$targets_spec" | tr ',' '\n' ;;
  esac
}

# clang integrated assembler shims: <dir>/<prefix>as -> clang -target <triple>
make_clang_shims() { # make_clang_shims DIR PREFIX TRIPLE
  local t c
  mkdir -p "$1"
  printf '#!/bin/sh\nexec clang -target %s -c -x assembler "$@"\n' "$3" > "$1/${2}as"
  chmod +x "$1/${2}as"
  # FPC's as_clang_* assemblers run "<prefix>clang" and pass -target themselves
  ln -sf "$(command -v clang)" "$1/${2}clang"
  for t in ar ranlib objcopy strip windres; do
    for c in llvm-$t llvm-$t-18 llvm-$t-19 llvm-$t-20; do
      if command -v "$c" >/dev/null 2>&1; then ln -sf "$(command -v "$c")" "$1/${2}$t"; break; fi
    done
  done
  if command -v ld.lld >/dev/null 2>&1; then ln -sf "$(command -v ld.lld)" "$1/${2}ld"; fi
}

# ---- steps ---------------------------------------------------------------------------------------
step_native() {
  [ -x "${bootstrap:-}" ] || { echo "--bootstrap PPC required for native" >&2; exit 2; }
  local tree=$work/tree-native lf=$logs/native.log
  : > "$lf"
  log "native: copy source"
  copy_tree "$tree"
  stamp_identity "$tree"
  log "native: make all ($host, bootstrap $("$bootstrap" -iV), -j$jobs)"
  local t0; t0=$(date +%s)
  (cd "$tree" && run_make "$lf" all FPC="$bootstrap" -j"$jobs" FPMAKEOPT="-T $jobs")
  rm -rf "$stage"
  (cd "$tree" && run_make "$lf" install FPC="$tree/compiler/$ppcname" INSTALL_PREFIX="$stage")
  echo "native	$host	ok	$(( $(date +%s) - t0 ))s" > "$work/native-status.tsv"
  log "native: done in $(( $(date +%s) - t0 ))s; $("$stage/lib/fpc/$FPC_VERSION/$ppcname" -iW)"
}

native_ppc() { echo "$stage/lib/fpc/$FPC_VERSION/$ppcname"; }

cross_one() { # cross_one LANE TARGET
  local lane=$1 t=$2 cpu os bu margs lf tree shimdir rc t0 extra=()
  cpu=${t%%-*}; os=${t#*-}
  bu=$(target_field "$t" 4); margs=$(target_field "$t" 5)
  [ "$bu" = "" ] && bu=-
  [ "$margs" = "-" ] && margs=
  local margv=()   # make_args: ';'-separated VAR=value items (values may contain spaces)
  if [ -n "$margs" ]; then
    # UNITDIR= and SMOKE= are for packaging and the smoke test, not for make
    IFS=";" read -r -a margv <<< "$(echo "$margs" | tr ';' '\n' | grep -vE '^(UNITDIR|SMOKE)=' | paste -sd';' -)"
  fi
  lf=$logs/cross-$t.log; : > "$lf"
  tree=$work/tree-lane$lane
  [ -d "$tree" ] || copy_tree "$tree"
  stamp_identity "$tree"
  case $bu in
    -) extra+=(BINUTILSPREFIX=) ;;
    clang:*) shimdir=$work/shims/$t; make_clang_shims "$shimdir" "$t-" "${bu#clang:}"
             extra+=(BINUTILSPREFIX="$t-" CROSSBINDIR="$shimdir") ;;
    *) extra+=(BINUTILSPREFIX="$bu") ;;
  esac
  t0=$(date +%s)
  set +e
  (cd "$tree" && run_make "$lf" crossall CPU_TARGET="$cpu" OS_TARGET="$os" FPC="$(native_ppc)" \
     -j"$jobs" FPMAKEOPT="-T $jobs" "${extra[@]}" ${margv[@]+"${margv[@]}"})
  rc=$?
  if [ $rc = 0 ]; then
    # serialize installs: targets of the same CPU install the same ppcross<cpu>
    (cd "$tree" && $lock make crossinstall CPU_TARGET="$cpu" OS_TARGET="$os" \
       FPC="$(native_ppc)" INSTALL_PREFIX="$stage" "${extra[@]}" ${margv[@]+"${margv[@]}"} >>"$lf" 2>&1)
    rc=$?
  fi
  local st=ok
  if [ $rc != 0 ] && grep -q "packages_all\|packages_smart" "$lf" && ! grep -q "rtl_all.*Error\|rtl_smart.*Error" "$lf"; then
    # RTL built but the packages step failed: ship compiler + RTL only (FPC's buildbase/installbase)
    echo "=== fallback: buildbase installbase (RTL only)" >> "$lf"
    (cd "$tree" && run_make "$lf" buildbase CROSSINSTALL=1 CPU_TARGET="$cpu" OS_TARGET="$os" FPC="$(native_ppc)" \
       -j"$jobs" "${extra[@]}" ${margv[@]+"${margv[@]}"} \
     && $lock make installbase CROSSINSTALL=1 CPU_TARGET="$cpu" OS_TARGET="$os" FPC="$(native_ppc)" \
       INSTALL_PREFIX="$stage" "${extra[@]}" ${margv[@]+"${margv[@]}"} >>"$lf" 2>&1) && { rc=0; st=rtl-only; }
  fi
  set -e
  local secs=$(( $(date +%s) - t0 ))
  [ $rc = 0 ] || st=FAIL
  printf '%s\t%s\t%s\t%ss\t%s\n' "$t" "$host" "$st" "$secs" "$(tail -n 3 "$lf" | tr '\t\n' '  ' | cut -c1-200)" >> "$work/cross-status.tsv"
  log "cross $t: $st (${secs}s)"
  return $rc
}

step_cross() {
  lock=; command -v flock >/dev/null 2>&1 && lock="flock $work/.install.lock"
  [ "$lanes" -gt 1 ] && [ -z "$lock" ] && { echo "--lanes >1 needs flock" >&2; exit 2; }
  [ -x "$(native_ppc)" ] || { echo "run the native step first" >&2; exit 1; }
  local list; list=$(select_targets)
  [ -n "$list" ] || { log "cross: no targets"; return 0; }
  log "cross: $(echo "$list" | wc -l | tr -d ' ') targets, $lanes lane(s)"
  local pids=() lane failed=0
  # lanes take the next target from a shared queue, so one slow target does not hold up a whole share
  echo "$list" > "$work/.queue"
  for lane in $(seq 1 "$lanes"); do
    (
      rcl=0
      while :; do
        if [ -n "$lock" ]; then
          t=$(flock "$work/.queue.lock" sh -c 'q=$1; t=$(head -n 1 "$q"); [ -n "$t" ] && tail -n +2 "$q" > "$q.tmp" && mv "$q.tmp" "$q"; echo "$t"' _ "$work/.queue")
        else
          t=$(head -n 1 "$work/.queue"); [ -n "$t" ] && { tail -n +2 "$work/.queue" > "$work/.queue.tmp"; mv "$work/.queue.tmp" "$work/.queue"; }
        fi
        [ -n "$t" ] || break
        if ! cross_one "$lane" "$t"; then
          rcl=1; [ $keepgoing = 1 ] || exit 1
        fi
      done
      exit $rcl
    ) &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p" || failed=1; done
  [ $failed = 0 ] || [ $keepgoing = 1 ] || { echo "cross: failures, see $work/cross-status.tsv" >&2; exit 1; }
}

# Canadian cross: toolchain that runs on HOST2 (Windows), built here. Layout = FPC's Windows layout:
#   <root>/bin/<host2>/{fpc.exe,ppc*.exe,ppcross*.exe,utils}  <root>/units/<target>/...
step_canadian() {
  local h2 cpu2 os2 tree lf root t tcpu
  for h2 in $(echo "$canadian" | tr ',' ' '); do
    cpu2=${h2%%-*}; os2=${h2#*-}
    tree=$work/tree-$h2; lf=$logs/canadian-$h2.log; : > "$lf"
    root=$work/stage-$h2
    copy_tree "$tree"; stamp_identity "$tree"
    # FPC= is always the native compiler: for another CPU the cycle first builds its own ppcross<cpu>
    local xppc; xppc=$(native_ppc)
    local bu; bu=$(target_field "$h2" 4); local extra=()
    case $bu in -|'') extra+=(BINUTILSPREFIX=) ;;
      clang:*) make_clang_shims "$work/shims/$h2" "$h2-" "${bu#clang:}"; extra+=(BINUTILSPREFIX="$h2-" CROSSBINDIR="$work/shims/$h2") ;;
      *) extra+=(BINUTILSPREFIX="$bu") ;; esac
    log "canadian $h2: make all (compiler runs on $h2)"
    # A cross "all" (no CROSSINSTALL) builds the compiler, RTL, packages and utils for OS_TARGET.
    # BUILDFULLNATIVE=1: also build the utils (fpcres, fpcmkcfg, instantfpc, ...) for the other host
    (cd "$tree" && run_make "$lf" all CPU_TARGET="$cpu2" OS_TARGET="$os2" FPC="$xppc" BUILDFULLNATIVE=1 -j"$jobs" FPMAKEOPT="-T $jobs" "${extra[@]}")
    rm -rf "$root"
    # UNIXHier= : use the non-Unix (Windows) install layout although the build host is Unix
    (cd "$tree" && run_make "$lf" install CPU_TARGET="$cpu2" OS_TARGET="$os2" FPC="$xppc" INSTALL_PREFIX="$root" UNIXHier= BUILDFULLNATIVE=1 "${extra[@]}")
    # FPC's Windows layout keeps every executable in bin\<host>\ (the utils' fpmake installs to bin\)
    for f in "$root"/bin/*; do [ -f "$f" ] && mv -f "$f" "$root/bin/$h2/"; done
    # Cross compilers that run on h2: build compiler/ for PPC_TARGET=<cpu> with OS/CPU_TARGET=h2.
    for t in $(awk -F'\t' -v h="$h2" '$0 !~ /^#/ && NF>=3 && $2!="excluded" && (","$3",") ~ (","h",") {print $1}' "$tsv"); do
      tcpu=${t%%-*}
      [ "$tcpu" = "$cpu2" ] && continue
      local cname; cname=$(compiler_suffix "$tcpu")
      if [ ! -f "$root/bin/$h2/ppcross$cname.exe" ]; then
        log "canadian $h2: ppcross$cname.exe"
        # Windows has no 80-bit Extended: x86 cross compilers need FPC's soft x80 (compiler/Makefile.fpc)
        # compiler sources are compiled for the Windows host: needs a compiler that targets cpu2
        local cppc=$xppc; [ "$cpu2" = "$host_cpu" ] || cppc=$tree/compiler/ppcross$(compiler_suffix "$cpu2")
        (cd "$tree/compiler" && run_make "$lf" "$tcpu" RELEASE=1 CPU_TARGET="$cpu2" OS_TARGET="$os2" FPC="$cppc" $(x87opt "$tcpu" 1) "${extra[@]}" \
            && cp "ppc$cname.exe" "$root/bin/$h2/ppcross$cname.exe") || { log "canadian $h2: ppcross$cname failed"; continue; }
      fi
    done
    log "canadian $h2: done"
  done
}

step_compilers() {
  [ -x "$(native_ppc)" ] || { echo "run the native step first" >&2; exit 1; }
  local tree=$work/tree-native cpus t c cname lf=$logs/compilers.log
  cpus=$(select_targets | cut -d- -f1 | sort -u)
  for c in $cpus; do
    [ "$c" = "$host_cpu" ] && continue
    cname=$(compiler_suffix "$c")
    [ -x "$stage/lib/fpc/$FPC_VERSION/ppcross$cname" ] && continue
    log "compilers: ppcross$cname"
    # hosts without 80-bit Extended need FPC's soft x80 for x86 cross compilers (compiler/Makefile.fpc)
    if (cd "$tree/compiler" && run_make "$lf" "$c" RELEASE=1 FPC="$(native_ppc)" -j"$jobs" $(x87opt "$c" "$([ "$host_cpu" = x86_64 ] || echo 1)")); then
      cp "$tree/compiler/ppc$cname" "$stage/lib/fpc/$FPC_VERSION/ppcross$cname"
      printf '%s	%s	compiler-only
' "ppcross$cname" "$host" >> "$work/cross-status.tsv"
    else
      printf '%s	%s	FAIL
' "ppcross$cname" "$host" >> "$work/cross-status.tsv"
      [ $keepgoing = 1 ] || exit 1
    fi
  done
}

x87opt() { # x87opt CPU NOEXTENDED -> LOCALOPT for x86 targets on hosts without 80-bit Extended
  case $1 in i386|i8086|x86_64) [ -n "${2:-}" ] && echo "LOCALOPT=-dFPC_SOFT_FPUX80" ;; esac
  return 0
}

compiler_suffix() {
  case $1 in i386) echo 386 ;; x86_64) echo x64 ;; aarch64) echo a64 ;; arm) echo arm ;; powerpc) echo ppc ;;
    powerpc64) echo ppc64 ;; m68k) echo 68k ;; sparc) echo sparc ;; sparc64) echo sparc64 ;; mips) echo mips ;;
    mipsel) echo mipsel ;; mips64) echo mips64 ;; mips64el) echo mips64el ;; avr) echo avr ;; jvm) echo jvm ;;
    i8086) echo 8086 ;; riscv32) echo rv32 ;; riscv64) echo rv64 ;; xtensa) echo xtensa ;; z80) echo z80 ;;
    wasm32) echo wasm32 ;; loongarch64) echo loongarch64 ;; *) echo "$1" ;; esac
}

step_finish() {
  local b=$stage/bin l=$stage/lib/fpc/$FPC_VERSION f
  # make every compiler reachable from bin/ with a relative link (crossinstall leaves absolute ones)
  for f in "$l"/ppc*; do
    [ -f "$f" ] || continue
    ln -sfn "../lib/fpc/$FPC_VERSION/$(basename "$f")" "$b/$(basename "$f")"
  done
  for f in "$b"/*; do
    if [ -L "$f" ]; then case $(readlink "$f") in /*) ln -sfn "../lib/fpc/$FPC_VERSION/$(basename "$(readlink "$f")")" "$f" ;; esac; fi
  done
  mkdir -p "$stage/share/fpc-toolchain" "$stage/etc"
  cp "$here/toolchain.conf" "$tsv" "$stage/share/fpc-toolchain/"
  for f in install.sh install.ps1 fpc-toolchain fpc-toolchain.ps1 fpc-sysroot.sh; do cp "$here/scripts/$f" "$stage/share/fpc-toolchain/"; done
  [ -d "$here/patches" ] && (cd "$here/patches" && ls *.patch 2>/dev/null) > "$stage/share/fpc-toolchain/patches.txt" || true
  {
    echo "identity=$identity"
    echo "tag=$tag"
    echo "repo=$TOOLCHAIN_REPO"
    echo "host=$host"
    cat "$src/.fpc-toolchain-source" 2>/dev/null || true
    echo "bootstrap=$( [ -x "${bootstrap:-}" ] && "$bootstrap" -iW || echo unknown)"
    echo "built_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "builder=${GITHUB_REPOSITORY:+github:$GITHUB_REPOSITORY/actions/runs/${GITHUB_RUN_ID:-?}}${GITHUB_REPOSITORY:-local:$(uname -n)}"
    echo "unit_targets=$(cd "$l/units" && ls | tr '\n' ' ')"
  } > "$stage/share/fpc-toolchain/BUILDINFO"
  [ -f "$work/cross-status.tsv" ] && cp "$work/cross-status.tsv" "$stage/share/fpc-toolchain/"
  # Windows-hosted roots get the same provenance
  for r in "$work"/stage-*; do
    [ -d "$r" ] || continue
    mkdir -p "$r/share/fpc-toolchain"
    cp "$here/toolchain.conf" "$tsv" "$r/share/fpc-toolchain/"
    cp "$here/scripts/install.ps1" "$r/share/fpc-toolchain/" 2>/dev/null || true
    sed -e "s/^host=.*/host=${r##*/stage-}/" -e "s/^unit_targets=.*/unit_targets=$(cd "$r/units" && ls | tr '\n' ' ')/" \
      "$stage/share/fpc-toolchain/BUILDINFO" > "$r/share/fpc-toolchain/BUILDINFO"
  done
  log "finish: $identity"
}

step_package() {
  local d=$work/dist; mkdir -p "$d"
  local name=$asset_id-$host u=$stage/lib/fpc/$FPC_VERSION/units t
  rm -rf "$work/pkg"; mkdir -p "$work/pkg/$name"
  # host archive: everything except the units of cross targets
  (cd "$stage" && tar --exclude="./lib/fpc/$FPC_VERSION/units/*" -cf - .) | (cd "$work/pkg/$name" && tar -xf -)
  mkdir -p "$work/pkg/$name/lib/fpc/$FPC_VERSION/units"
  cp -R "$u/$host" "$work/pkg/$name/lib/fpc/$FPC_VERSION/units/"
  (cd "$work/pkg" && tar -cf - "$name" | xz -T0 -6 > "$d/$name.tar.xz")
  log "package: $name.tar.xz $(du -h "$d/$name.tar.xz" | cut -f1)"
  if [ $unitarchives = 1 ]; then
    # one archive per target (incl. this host's own: other hosts cross-compile to it), with the units in the
    # directory its compiler searches (UNITDIR=; make install splits some targets over two directories)
    local seen=" " ud ux src
    for ud in $(cd "$u" && ls); do
      t=$(unitdir_target "$ud"); [ -n "$t" ] || t=$ud
      case "$seen" in *" $t "*) continue ;; esac; seen="$seen$t "
      [ "$(target_field "$t" 2)" = excluded ] && continue
      ux=$(target_field "$t" 5 | tr ';' '\n' | sed -n 's/^UNITDIR=//p'); [ -n "$ux" ] || ux=$t
      rm -rf "$work/pkg-units"; mkdir -p "$work/pkg-units/$ux"
      for src in "$u/$t" "$u/$ux"; do [ -d "$src" ] && cp -R "$src/." "$work/pkg-units/$ux/"; done
      (cd "$work/pkg-units" && tar -cf - "$ux" | xz -T0 -6 > "$d/$asset_id-units-$t.tar.xz")
      # Windows hosts install with PowerShell (Expand-Archive): zip for the targets they ship
      if [ -n "$(target_field "$t" 3 | tr ',' '\n' | grep -- '-win64$')" ]; then
        (cd "$work/pkg-units" && rm -f "$d/$asset_id-units-$t.zip" && zip -qr -9 "$d/$asset_id-units-$t.zip" "$ux")
      fi
    done
    rm -rf "$work/pkg-units"
    log "package: $(find "$d" -name '*-units-*.tar.xz' | wc -l | tr -d ' ') unit archives"
  fi
  for r in "$work"/stage-*; do
    [ -d "$r" ] || continue
    local n2=$asset_id-${r##*/stage-}
    rm -rf "${work:?}/pkg/$n2"; cp -R "$r" "$work/pkg/$n2"
    (cd "$work/pkg" && rm -f "$d/$n2.zip" && zip -qr -9 "$d/$n2.zip" "$n2")
    log "package: $n2.zip $(du -h "$d/$n2.zip" | cut -f1)"
  done
  local sha="sha256sum"; command -v sha256sum >/dev/null 2>&1 || sha="shasum -a 256"
  (cd "$d" && for f in *.tar.xz *.zip; do if [ -f "$f" ]; then $sha "$f"; fi; done > "SHA256SUMS.$host")
  rm -rf "$work/pkg"
}

for s in "${steps[@]}"; do
  case $s in
    native) step_native ;;
    cross) step_cross ;;
    compilers) step_compilers ;;
    canadian) step_canadian ;;
    finish) step_finish ;;
    package) step_package ;;
    *) echo "unknown step $s" >&2; exit 2 ;;
  esac
done
