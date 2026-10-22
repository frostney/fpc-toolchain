#!/bin/sh
# install.sh — install an fpc-toolchain build side by side with other FPC versions (Linux, macOS).
#
#   install.sh [options] [IDENTITY]
#
# What to install (one of):
#   IDENTITY             e.g. 3.3.1+1 or 3.2.4-rc2+1 (what `fpc -iW` prints), or its release tag
#                        3.3.1-b1 / 3.2.4-rc2-b1: download from the GitHub release of that tag
#   --lock FILE          install the toolchain pinned in a project's toolchain.lock (and check its sha256)
#   --from FILE.tar.xz   install a downloaded/locally built tarball
#   --from-dir DIR       install an unpacked tree (copied)
# Options:
#   --root DIR           install root (default $FPC_TOOLCHAIN_ROOT or ~/.local/share/fpc-toolchains)
#   --repo OWNER/NAME    GitHub repository (default frostney/fpc-toolchain)
#   --host HOST          host to download for (default: this machine, e.g. x86_64-linux, aarch64-darwin)
#   --targets LIST       cross targets whose units to install: comma list, "all", or "none"
#                        (default: the lock's `targets`, else none; the host's own units are always there)
#   --sums-sha256 HEX    expected sha256 of the release's SHA256SUMS file (pins every asset; the lock's
#                        `sha256sums`); without it the downloaded SHA256SUMS is trusted (HTTPS)
#   --no-activate        do not make this build the active one for its version
#   --default            also make it the plain `fpc` in ROOT/bin
#
# Layout (ROOT):
#   toolchains/<identity>/     the unpacked build: bin/ lib/fpc/<version>/ etc/fpc.cfg share/fpc-toolchain/
#   toolchains/<version>       -> <identity> (active build of that version)
#   bin/fpc-<version>          front-end: the active build's driver, reading only that build's fpc.cfg
#   bin/ppc<cpu>-<version>     compilers for FPC's native `fpc -V<version>` selection
#   bin/fpc-toolchain          helper: env | which | list | doctor
#   etc/fpc.cfg                shared config that dispatches on the compiler version (used by `fpc -V`)
set -eu

root=${FPC_TOOLCHAIN_ROOT:-$HOME/.local/share/fpc-toolchains}
repo='' host='' sumsha='' from='' fromdir='' lock='' ident='' activate=1 makedefault=0 targets=''

die() { echo "install.sh: $*" >&2; exit 1; }
while [ $# -gt 0 ]; do
  case $1 in
    --root) root=$2; shift 2 ;;
    --repo) repo=$2; shift 2 ;;
    --host) host=$2; shift 2 ;;
    --sums-sha256) sumsha=$2; shift 2 ;;
    --targets) targets=$2; shift 2 ;;
    --from) from=$2; shift 2 ;;
    --from-dir) fromdir=$2; shift 2 ;;
    --lock) lock=$2; shift 2 ;;
    --no-activate) activate=0; shift ;;
    --default) makedefault=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) ident=$1; shift ;;
  esac
done

if [ -z "$host" ]; then
  case $(uname -m) in x86_64|amd64) cpu=x86_64 ;; aarch64|arm64) cpu=aarch64 ;; *) die "unsupported cpu $(uname -m)" ;; esac
  case $(uname -s) in Linux) os=linux ;; Darwin) os=darwin ;; *) die "unsupported OS $(uname -s); on Windows use install.ps1" ;; esac
  host=$cpu-$os
fi

sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

# toolchain.lock: simple key = value lines (see DESIGN.md)
lockval() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}[[:space:]]*$/\1/p" "$lock" | head -n 1; }
if [ -n "$lock" ]; then
  [ -f "$lock" ] || die "no lock file $lock"
  ident=$(lockval identity); [ -n "$ident" ] || die "$lock has no identity"
  [ -n "$repo" ] || repo=$(lockval repo)
  [ -n "$sumsha" ] || sumsha=$(lockval sha256sums)
  [ -n "$targets" ] || targets=$(lockval targets)
fi

# identity "<ver>+N" <-> release tag "<ver>-bN"
case $ident in
  *+*) ;;
  *-b[0-9]*) ident=$(echo "$ident" | sed 's/-b\([0-9][0-9]*\)$/+\1/') ;;
esac
tag=$(echo "$ident" | sed 's/+/-b/')

tmp=$(mktemp -d "${TMPDIR:-/tmp}/fpc-toolchain.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

assetid=; base=; sums=
fetch() { # fetch ASSET -> $tmp/ASSET, verified against SHA256SUMS
  [ -f "$tmp/$1" ] && return 0
  if [ -n "$base" ]; then curl -fsSL --retry 3 -o "$tmp/$1" "$base/$1" || die "download $base/$1 failed"
  elif [ -f "$srcdir/$1" ]; then cp "$srcdir/$1" "$tmp/$1"
  else die "no $1 next to $from"; fi
  if [ -n "$sums" ]; then
    want=$(awk -v a="$1" '$2==a || $2=="*"a {print $1}' "$sums")
    [ -n "$want" ] || die "$1 not listed in SHA256SUMS"
    [ "$(sha256 "$tmp/$1")" = "$want" ] || die "sha256 mismatch for $1"
  fi
}
if [ -z "$from" ] && [ -z "$fromdir" ]; then
  [ -n "$ident" ] || die "say what to install: IDENTITY, --lock, --from or --from-dir"
  ver=${ident%%[-+]*}
  [ -n "$repo" ] || repo=frostney/fpc-toolchain
  assetid="fpc-$tag"
  base="https://github.com/$repo/releases/download/$tag"
  curl -fsSL --retry 3 -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" || die "no SHA256SUMS in release $ident of $repo"
  if [ -n "$sumsha" ]; then [ "$(sha256 "$tmp/SHA256SUMS")" = "$sumsha" ] || die "SHA256SUMS of $ident does not match the pinned sha256sums"; fi
  sums=$tmp/SHA256SUMS
  echo "downloading $base/$assetid-$host.tar.xz" >&2
  fetch "$assetid-$host.tar.xz"
  from=$tmp/$assetid-$host.tar.xz
elif [ -n "$from" ]; then
  srcdir=$(cd "$(dirname "$from")" && pwd)
  assetid=$(basename "$from" | sed "s/-$host\.tar\.xz\$//")
  for f in "$srcdir"/SHA256SUMS*; do [ -f "$f" ] && cat "$f"; done > "$tmp/SHA256SUMS"
  [ -s "$tmp/SHA256SUMS" ] && sums=$tmp/SHA256SUMS
fi

if [ -n "$from" ]; then
  [ -f "$from" ] || die "no file $from"
  if [ -n "$sums" ] && [ "$from" != "$tmp/$assetid-$host.tar.xz" ]; then
    want=$(awk -v a="$(basename "$from")" '$2==a {print $1}' "$sums")
    [ -z "$want" ] || [ "$(sha256 "$from")" = "$want" ] || die "sha256 mismatch for $from"
  fi
  mkdir "$tmp/x"; xz -dc "$from" | (cd "$tmp/x" && tar -xf -)
  fromdir=$(find "$tmp/x" -mindepth 1 -maxdepth 1 -type d | head -n 1)
fi
[ -f "$fromdir/share/fpc-toolchain/BUILDINFO" ] || die "$fromdir is not an fpc-toolchain tree (no share/fpc-toolchain/BUILDINFO)"

info() { sed -n "s/^$1=//p" "$fromdir/share/fpc-toolchain/BUILDINFO" | head -n 1; }
bident=$(info identity); bhost=$(info host)
[ -z "$ident" ] || [ "$ident" = "$bident" ] || die "tarball is $bident, expected $ident"
[ "$bhost" = "$host" ] || die "tarball is for $bhost, this host is $host"
ver=${bident%%[-+]*}
dest=$root/toolchains/$bident

mkdir -p "$root/toolchains" "$root/bin" "$root/etc"
rm -rf "$dest.new"; mkdir -p "$dest.new"
(cd "$fromdir" && tar -cf - .) | (cd "$dest.new" && tar -xf -)

# --- cross target units (one archive per target, shared by all hosts) -------------------------------
if [ -n "$targets" ] && [ "$targets" != none ]; then
  [ -n "$assetid" ] || die "--targets needs a release or --from archive (unit archives live next to it)"
  alltargets=0
  if [ "$targets" = all ]; then
    alltargets=1
    # every target this host ships (targets.tsv hosts column)
    targets=$(awk -F'\t' -v h="$host" '$0 !~ /^#/ && $2!="excluded" && $1!=h && (","$3",") ~ (","h",") {print $1}' \
      "$fromdir/share/fpc-toolchain/targets.tsv" | tr '\n' ' ')
  fi
  for t in $(echo "$targets" | tr ',' ' '); do
    [ "$t" = "$host" ] && continue
    if [ $alltargets = 1 ] && [ -n "$sums" ] && ! grep -q " \*\{0,1\}$assetid-units-$t\.tar\.xz\$" "$sums"; then
      echo "  - units $t: not in this release, skipped" >&2; continue
    fi
    fetch "$assetid-units-$t.tar.xz"
    xz -dc "$tmp/$assetid-units-$t.tar.xz" | (cd "$dest.new/lib/fpc/$ver/units" && tar -xf -)
    rm -f "$tmp/$assetid-units-$t.tar.xz"
    echo "  + units $t" >&2
  done
fi

# --- 3.2.x on Apple Silicon: x86 targets through the x86_64-darwin build under Rosetta 2 ------------------
x86=$(for t in $(echo "$targets" | tr ',' ' '); do case $t in i386-*|i8086-*|x86_64-*) echo "$t" ;; esac; done)
if [ "$host" = aarch64-darwin ] && [ -n "$x86" ] && grep -q '^ROSETTA_X86=1' "$dest.new/share/fpc-toolchain/toolchain.conf"; then
  [ -n "$assetid" ] || die "x86 targets on Apple Silicon need the x86_64-darwin archive next to $from"
  fetch "$assetid-x86_64-darwin.tar.xz"
  mkdir -p "$dest.new/rosetta"
  xz -dc "$tmp/$assetid-x86_64-darwin.tar.xz" | (cd "$dest.new/rosetta" && tar -xf - --strip-components=1)
  rm -f "$tmp/$assetid-x86_64-darwin.tar.xz"
  for c in ppcrossx64:ppcx64 ppcross386:ppcross386 ppcross8086:ppcross8086; do
    w=${c%%:*}; real="$dest/rosetta/lib/fpc/$ver/${c#*:}"
    [ -f "$dest.new/rosetta/lib/fpc/$ver/${c#*:}" ] || continue
    printf '#!/bin/sh
# x86 cross compiler of the x86_64-darwin build, run by Rosetta 2 (FPC 3.2.x has no arm64-hosted one)
exec "%s" -n "@%s" "$@"
' \
      "$real" "$dest/etc/fpc.cfg" > "$dest.new/lib/fpc/$ver/$w"
    chmod +x "$dest.new/lib/fpc/$ver/$w"; ln -sfn "../lib/fpc/$ver/$w" "$dest.new/bin/$w"
  done
  arch -x86_64 /usr/bin/true 2>/dev/null || echo "warning: Rosetta 2 is not installed (softwareupdate --install-rosetta); x86 targets need it" >&2
  echo "  + x86 targets through the x86_64-darwin build (Rosetta 2)" >&2
fi

# --- per-build fpc.cfg (FPC's own template via fpcmkcfg, plus cross binutils prefixes) -------------
cfg=$dest/etc/fpc.cfg
mkdir -p "$dest.new/etc"
"$dest.new/bin/fpcmkcfg" -d "basepath=$dest/lib/fpc/\$fpcversion" -o "$dest.new/etc/fpc.cfg" >/dev/null
{
  echo ""
  echo "# --- fpc-toolchain $bident: cross binutils (targets.tsv binutils column; empty = internal/clang) ---"
  echo "#IFDEF FPC_CROSSCOMPILING"
  # cross binutils shipped with this build (built from GNU binutils sources, see the release's binutils-*.tar.xz)
  [ -d "$dest.new/cross/bin" ] && echo "-FD$dest/cross/bin"
  awk -F'\t' '$0 !~ /^#/ && NF>=4 && $2!="excluded" {print $1 "\t" $4 "\t" $5}' "$dest.new/share/fpc-toolchain/targets.tsv" |
  while IFS="$(printf '\t')" read -r t bu margs; do
    cpu=${t%%-*}; os=${t#*-}
    case $bu in -|clang:*) xp= ;; *) xp=$bu ;; esac
    # FPC config defines: CPU<CPU> and the target OS symbol (upper case)
    ucpu=$(echo "$cpu" | tr 'a-z' 'A-Z'); uos=$(echo "$os" | tr 'a-z' 'A-Z')
    case $cpu in i386) ucpu=I386 ;; x86_64) ucpu=X86_64 ;; powerpc) ucpu=POWERPC ;; powerpc64) ucpu=POWERPC64 ;; armeb) ucpu=ARM; uos="$uos FPC_BIG_ENDIAN" ;; esac
    case $os in win64) uos=WIN64 ;; win32) uos=WIN32 ;; wasip1) uos=WASIP1 ;; wasip1threads) uos=WASIP1THREADS ;; wasip2) uos=WASIP2 ;; esac
    printf '#IFDEF CPU%s\n' "$ucpu"
    n=0; for d in $uos; do printf '#IFDEF %s\n' "$d"; n=$((n+1)); done
    printf -- '-XP%s\n' "$xp"
    # options the target's RTL was built with (CROSSOPT in targets.tsv), e.g. -Aas for GNU as on Solaris
    case ";$margs;" in *";CROSSOPT="*) echo "$margs" | tr ';' '\n' | sed -n 's/^CROSSOPT=//p' | tr ' ' '\n' | grep . ;; esac
    while [ $n -gt 0 ]; do printf '#ENDIF\n'; n=$((n-1)); done
    printf '#ENDIF\n'
  done
  echo "#ENDIF FPC_CROSSCOMPILING"
  # macOS: link Darwin targets against the active Xcode / Command Line Tools SDK
  if [ "$(uname -s)" = Darwin ] && sdk=$(xcrun --show-sdk-path 2>/dev/null); then
    printf '#IFDEF DARWIN\n-XR%s\n#ENDIF\n' "$sdk"
  fi
} >> "$dest.new/etc/fpc.cfg"
# Linux resolves the compiler's own path (/proc/self/exe), so it looks for <lib/fpc>/../etc/fpc.cfg
ln -sfn ../../etc "$dest.new/lib/fpc/etc"

# --- activate ---------------------------------------------------------------------------------------
rm -rf "$dest"; mv "$dest.new" "$dest"
if [ $activate = 1 ]; then
  ln -sfn "$bident" "$root/toolchains/$ver.new" && mv -f "$root/toolchains/$ver.new" "$root/toolchains/$ver" 2>/dev/null \
    || { rm -f "$root/toolchains/$ver"; ln -s "$bident" "$root/toolchains/$ver"; }
fi

regen_shims() {
  # remove our old shims, then recreate for every active version
  for f in "$root"/bin/*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    if [ -L "$f" ]; then case $(readlink "$f") in ../toolchains/*) rm -f "$f" ;; esac; fi
    case $(basename "$f") in fpc-[0-9]*) grep -q 'fpc-toolchain front-end' "$f" 2>/dev/null && rm -f "$f" ;; esac
  done
  : > "$root/etc/fpc.cfg.new"
  echo "# fpc-toolchain shared config: dispatches on the compiler version (generated; do not edit)" >> "$root/etc/fpc.cfg.new"
  for a in "$root"/toolchains/*; do
    [ -L "$a" ] || continue
    v=$(basename "$a")
    printf '#!/bin/sh\n# fpc-toolchain front-end for FPC %s (generated)\nexec "%s/toolchains/%s/bin/fpc" -n "@%s/toolchains/%s/etc/fpc.cfg" "$@"\n' \
      "$v" "$root" "$v" "$root" "$v" > "$root/bin/fpc-$v"
    chmod +x "$root/bin/fpc-$v"
    for c in "$a/lib/fpc/$v"/ppc*; do
      [ -f "$c" ] || continue
      ln -sfn "../toolchains/$v/lib/fpc/$v/$(basename "$c")" "$root/bin/$(basename "$c")-$v"
    done
    printf '#IFDEF VER%s\n#INCLUDE %s/toolchains/%s/etc/fpc.cfg\n#ENDIF\n' "$(echo "$v" | tr . _)" "$root" "$v" >> "$root/etc/fpc.cfg.new"
  done
  mv -f "$root/etc/fpc.cfg.new" "$root/etc/fpc.cfg"
  if [ -f "$root/etc/default" ]; then
    dv=$(cat "$root/etc/default")
    for t in fpc fpcres fpcmkcfg instantfpc fpcmake fppkg; do
      [ -e "$root/toolchains/$dv/bin/$t" ] && ln -sfn "../toolchains/$dv/bin/$t" "$root/bin/$t"
    done
  fi
}
[ $makedefault = 1 ] && echo "$ver" > "$root/etc/default"
regen_shims

# helper
for h in fpc-toolchain fpc-sysroot.sh; do
  if [ -f "$dest/share/fpc-toolchain/$h" ]; then cp "$dest/share/fpc-toolchain/$h" "$root/bin/${h%.sh}"; chmod +x "$root/bin/${h%.sh}"; fi
done

echo "installed $bident -> $dest"
"$dest/bin/fpc" -n "@$cfg" -iW >/dev/null 2>&1 || die "installed compiler does not run"
got=$("$dest/lib/fpc/$ver/$(cd "$dest/lib/fpc/$ver" && ls ppcx64 ppca64 2>/dev/null | head -n 1)" -iW)
[ "$got" = "$bident" ] || die "compiler reports $got, expected $bident"
case ":$PATH:" in *":$root/bin:"*) ;; *) echo "add $root/bin to PATH (fpc-$ver, fpc -V$ver)" >&2 ;; esac
for c in "$HOME/.fpc.cfg" ./fpc.cfg; do
  [ -f "$c" ] && echo "warning: $c exists and takes precedence over the toolchain's fpc.cfg for plain fpc/ppc calls (fpc-$ver front-ends ignore it)" >&2
done
exit 0
