#!/usr/bin/env bash
# action-test-plan.sh VERSION [HOST] — for the action test: does this version ship this runner's host (or HOST),
# and which cross target to test there (the first of a fixed preference list that the host ships).
# Writes host=, ship= and cross= to $GITHUB_OUTPUT.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/scripts/lib.sh"
load_version "${1:?usage: action-test-plan.sh VERSION}"
h=${2:-}
[ -n "$h" ] || case "${RUNNER_OS}-${RUNNER_ARCH}" in
  Linux-X64) h=x86_64-linux ;; Linux-ARM64) h=aarch64-linux ;; macOS-ARM64) h=aarch64-darwin ;;
  macOS-X64) h=x86_64-darwin ;; Windows-X64) h=x86_64-win64 ;; Windows-ARM64) h=aarch64-win64 ;; *) h=unknown ;;
esac
case " $TOOLCHAIN_HOSTS " in *" $h "*) ship=true ;; *) ship=false ;; esac
cross=
for t in x86_64-win64 wasm32-wasip1 arm-wince i386-win32; do
  [ "$t" = "$h" ] && continue
  if awk -F'\t' -v t="$t" -v h="$h" '$0 !~ /^#/ && $1==t && $2!="excluded" && (","$3",") ~ (","h",") {f=1} END {exit !f}' "$tsv"; then
    cross=$t; break
  fi
done
echo "host $h ship=$ship cross=$cross"
{ echo "host=$h"; echo "ship=$ship"; echo "cross=$cross"; } >> "$GITHUB_OUTPUT"
