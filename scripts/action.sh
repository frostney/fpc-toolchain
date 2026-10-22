#!/usr/bin/env bash
# action.sh resolve|install|sysroots — the steps of action.yml (bash on every runner, Git Bash on Windows).
# Inputs come from the environment (INPUT_*); results go to $GITHUB_OUTPUT and $GITHUB_PATH.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/scripts/lib.sh"
err() { echo "::error title=fpc-toolchain::$*" >&2; exit 1; }
out() { echo "$1=$2" >> "$GITHUB_OUTPUT"; }
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }
unixpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else echo "$1"; fi; }
toolcache=$(unixpath "${RUNNER_TOOL_CACHE:?}")
field() { awk -F'\t' -v t="$1" -v c="$2" '$0 !~ /^#/ && $1==t {print $c; exit}' "$tsv"; }

host_id() {
  case "${RUNNER_OS}-${RUNNER_ARCH}" in
    Linux-X64) echo x86_64-linux ;; Linux-ARM64) echo aarch64-linux ;;
    macOS-ARM64) echo aarch64-darwin ;; macOS-X64) echo x86_64-darwin ;;
    Windows-X64) echo x86_64-win64 ;; Windows-ARM64) echo aarch64-win64 ;;
    *) err "unsupported runner ${RUNNER_OS} ${RUNNER_ARCH}" ;;
  esac
}

resolve() {
  local host repo tag targets t cls hosts dir hash spec
  # version: 3.2.4 (newest build), a tag 3.2.4-rc2-b1 or build 3.2.4-rc2+1 (that build), else toolchain.lock
  spec=${INPUT_VERSION:-}
  if [ -z "$spec" ] && [ -f "${GITHUB_WORKSPACE:-.}/toolchain.lock" ]; then
    spec=$(sed -n 's/^[[:space:]]*identity[[:space:]]*=[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' "${GITHUB_WORKSPACE:-.}/toolchain.lock" | head -n 1)
  fi
  [ -n "$spec" ] || err "say which FPC: version: 3.2.4 (or 3.3.1, or a build like 3.2.4-rc2-b1), or commit a toolchain.lock"
  vdir=$(version_dir "$spec") || err "unknown FPC version $spec (have: $(cd "$root/versions" && echo *))"
  # shellcheck source=/dev/null
  . "$vdir/toolchain.conf"; tsv=$vdir/targets.tsv
  host=$(host_id)
  case " $TOOLCHAIN_HOSTS " in *" $host "*) ;; *) err "FPC $FPC_VERSION has no toolchain for $host (hosts: $TOOLCHAIN_HOSTS)" ;; esac
  # targets: sorted, unique, without the host itself; each must be shipped for this host
  targets=$(echo "${INPUT_TARGETS:-}" | tr ', ' '\n\n' | grep . | sort -u | grep -vx "$host" | tr '\n' ',' | sed 's/,$//') || true
  for t in $(echo "$targets" | tr ',' ' '); do
    cls=$(field "$t" 2); hosts=$(field "$t" 3)
    [ -n "$cls" ] || err "unknown target $t (see versions/$FPC_VERSION/MATRIX.md)"
    [ "$cls" != excluded ] || err "target $t is not shipped: $(field "$t" 7)"
    case ",$hosts," in *",$host,"*) ;; *) err "target $t is not available on $host hosts (shipped on: $hosts). $(field "$t" 7)" ;; esac
  done
  repo=${INPUT_REPOSITORY:-${ACTION_REPOSITORY:-}}; repo=${repo:-$GITHUB_REPOSITORY}
  case $spec in
    *+[0-9]*|*-b[0-9]*) tag=$(echo "$spec" | sed 's/+/-b/') ;;
    *) tag=$(gh api "repos/$repo/releases?per_page=100" \
             --jq "[.[] | select(.draft == false) | select(.tag_name | startswith(\"$FPC_VERSION-\"))][0].tag_name") \
         || err "cannot list releases of $repo"
       [ -n "$tag" ] && [ "$tag" != null ] || err "$repo has no published FPC $FPC_VERSION release" ;;
  esac
  hash=$(printf '%s' "$targets" | (sha256sum 2>/dev/null || shasum -a 256) | cut -c1-12)
  dir="$toolcache/fpc-toolchain/$tag/$host-$hash"
  out vdir "$vdir"
  out host "$host"; out repo "$repo"; out tag "$tag"; out targets "$targets"
  out identity "$(echo "$tag" | sed 's/-b\([0-9][0-9]*\)$/+\1/')"; out version "$FPC_VERSION"
  out dir "$(winpath "$dir")"; out key "fpc-toolchain-$repo-$tag-$host-$hash"
}

install() {
  # shellcheck source=/dev/null
  . "$INPUT_VDIR/toolchain.conf"
  local dir host=$INPUT_HOST tag=$INPUT_TAG id=$INPUT_IDENTITY v=$FPC_VERSION tmp asset hit=true t
  dir=$(unixpath "$INPUT_DIR")
  if [ ! -f "$dir/.complete" ]; then
    hit=false
    tmp=$(mktemp -d)
    case $host in *-win64) asset="fpc-$tag-$host.zip" ;; *) asset="fpc-$tag-$host.tar.xz" ;; esac
    # 3.2.x on Apple Silicon: x86 targets need the x86_64-darwin build (run by Rosetta 2)
    local extra=""
    if [ "$host" = aarch64-darwin ] && [ "${ROSETTA_X86:-0}" = 1 ] && echo ",$INPUT_TARGETS," | grep -qE ',(i386|i8086|x86_64)-'; then
      extra="fpc-$tag-x86_64-darwin.tar.xz"
    fi
    if [ -n "${INPUT_ARCHIVES:-}" ]; then
      cp "$INPUT_ARCHIVES/$asset" "$INPUT_ARCHIVES"/SHA256SUMS* "$tmp/"
      [ -z "$extra" ] || cp "$INPUT_ARCHIVES/$extra" "$tmp/"
      for t in $(echo "$INPUT_TARGETS" | tr ',' ' '); do cp "$INPUT_ARCHIVES/fpc-$tag-units-$t".* "$tmp/" 2>/dev/null || true; done
    else
      local pats=(-p "$asset" -p SHA256SUMS)
      [ -z "$extra" ] || pats+=(-p "$extra")
      for t in $(echo "$INPUT_TARGETS" | tr ',' ' '); do
        case $host in *-win64) pats+=(-p "fpc-$tag-units-$t.zip") ;; *) pats+=(-p "fpc-$tag-units-$t.tar.xz") ;; esac
      done
      gh release download "$tag" -R "$INPUT_REPO" -D "$tmp" "${pats[@]}" || err "cannot download $tag from $INPUT_REPO"
    fi
    rm -rf "$dir"; mkdir -p "$dir"
    # the installers verify every archive against SHA256SUMS next to it
    case $host in
      *-win64) pwsh -NoProfile -File "$(winpath "$here/scripts/install.ps1")" -Root "$(winpath "$dir")" \
                 -From "$(winpath "$tmp/$asset")" -Targets "${INPUT_TARGETS:-none}" -HostId "$host" ;;
      *) sh "$here/scripts/install.sh" --root "$dir" --from "$tmp/$asset" --targets "${INPUT_TARGETS:-none}" ;;
    esac
    rm -rf "$tmp"
    touch "$dir/.complete"
  fi
  local tree bindir fe fpcexe
  case $host in
    *-win64)
      tree="$dir/toolchains/$id"; bindir="$tree/bin/$host"; fe="$dir/bin/fpc-$v.cmd"
      # a restored cache may lack the junction and the front-end: recreate both
      pwsh -NoProfile -Command "\$l = '$(winpath "$dir/toolchains/$v")'; if (-not (Test-Path \$l)) { New-Item -ItemType Junction -Path \$l -Target '$(winpath "$tree")' | Out-Null }"
      printf '@echo off\r\n"%s" -n "@%s" %%*\r\n' "$(winpath "$bindir/fpc.exe")" "$(winpath "$bindir/fpc.cfg")" > "$fe"
      fpcexe="$bindir/fpc.exe" ;;
    *) tree="$dir/toolchains/$id"; bindir="$tree/bin"; fe="$dir/bin/fpc-$v"; fpcexe=$fe ;;
  esac
  local got; got=$("$fpcexe" -iW | tr -d '\r') || err "installed compiler does not run"
  [ "$got" = "$id" ] || err "cached toolchain reports $got, expected $id"
  winpath "$dir/bin" >> "$GITHUB_PATH"
  # aarch64-win64 (and the Darwin targets) assemble with clang: GitHub's Windows images ship LLVM here
  case $host in *-win64)
    if ! command -v clang >/dev/null 2>&1; then
      if [ -x "/c/Program Files/LLVM/bin/clang.exe" ]; then echo 'C:\Program Files\LLVM\bin' >> "$GITHUB_PATH"
      else echo "::warning title=fpc-toolchain::clang not found; aarch64-win64 and Darwin targets need LLVM clang on PATH"; fi
    fi ;;
  esac
  [ "${INPUT_FPC:-true}" = true ] && winpath "$bindir" >> "$GITHUB_PATH"
  out path "$tree"; out root "$dir"; out tool-cache-hit "$hit"
  echo "fpc $id for $host from $INPUT_REPO (targets: ${INPUT_TARGETS:-none}; tool cache hit: $hit)"
}

sysroots() {
  local t d n=0 last=""
  [ "${RUNNER_OS}" != Windows ] || err "sysroots are fetched with ar and tar on Linux and macOS runners only"
  for t in $(echo "${INPUT_SYSROOTS:-}" | tr ', ' '\n\n' | grep . | sort -u); do
    d="$toolcache/fpc-sysroot/$t"
    # shellcheck disable=SC2086
    [ -f "$d/fpc-options" ] || sh "$here/scripts/fpc-sysroot.sh" "$t" "$d" ${INPUT_SYSROOT_PACKAGES:-}
    echo "sysroot $t: $(cat "$d/fpc-options")"
    n=$((n + 1)); last=$d
  done
  # <dir>/<target>/fpc-options holds the FPC options for each sysroot
  out sysroot-dir "$toolcache/fpc-sysroot"
  [ $n = 1 ] && out sysroot-options "$(cat "$last/fpc-options")"
  return 0
}

sysroot_key() {
  local list
  list=$(echo "${INPUT_SYSROOTS:-}" | tr ', ' '\n\n' | grep . | sort -u | tr '\n' ',' | sed 's/,$//') || true
  out sysroot-key "fpc-sysroot-${RUNNER_OS}-${RUNNER_ARCH}-${list}-$(printf '%s' "${INPUT_SYSROOT_PACKAGES:-}" | tr ' ' ',')"
  echo "sysroot-paths<<EOF" >> "$GITHUB_OUTPUT"; echo "$list" | tr ',' '\n' | grep . | sed "s|^|$toolcache/fpc-sysroot/|" >> "$GITHUB_OUTPUT"; echo "EOF" >> "$GITHUB_OUTPUT"
}

case ${1:-} in
  resolve) resolve ;;
  install) install ;;
  sysroot-key) sysroot_key ;;
  sysroots) sysroots ;;
  *) echo "usage: action.sh resolve|install|sysroot-key|sysroots" >&2; exit 2 ;;
esac
