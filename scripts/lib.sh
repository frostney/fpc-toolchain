# lib.sh — sourced by the bash scripts. Repository root, and the per-version data in versions/<x.y.z>/.
# shellcheck shell=bash
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# version_dir SPEC: SPEC is a version (3.2.4), a release tag (3.2.4-rc2-b1) or a build (3.2.4-rc2+1)
version_dir() {
  local v=${1%%[-+]*}
  if [ -z "$v" ] || [ ! -f "$root/versions/$v/toolchain.conf" ]; then
    echo "unknown FPC version '${1}' (have: $(cd "$root/versions" && echo *))" >&2; return 1
  fi
  echo "$root/versions/$v"
}

# load_version SPEC: sets vdir, tsv and the toolchain.conf variables
load_version() {
  vdir=$(version_dir "$1") || exit 2
  # shellcheck source=/dev/null
  . "$vdir/toolchain.conf"
  tsv=$vdir/targets.tsv
}
