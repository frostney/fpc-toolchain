#!/bin/sh
# check-install-activation.sh — install.sh makes each new build the active one for its version.
#
#   check-install-activation.sh
#
# Installs stand-in builds (shell scripts that print their identity, no compiler) with --from-dir into a
# temporary root: two builds of one version in turn, the first again, one with --no-activate, and one with
# an mv that has neither -T nor -h.
# After each, toolchains/<version> must point at the expected build, nothing may be left beside it or
# inside another build, and fpc-<version> must run that build. Needs no network.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/fpc-activation.XXXXXX")
trap 'rm -rf "$work"' EXIT
root=$work/root
fails=0

# stand-in IDENTITY: an unpacked build tree for host "test-host" whose tools print IDENTITY
standin() {
  dir=$work/src/$1; ver=${1%%[-+]*}
  mkdir -p "$dir/bin" "$dir/lib/fpc/$ver/units" "$dir/share/fpc-toolchain"
  printf 'identity=%s\nhost=test-host\n' "$1" > "$dir/share/fpc-toolchain/BUILDINFO"
  printf '# target\tstatus\thosts\tbinutils\tmake args\n' > "$dir/share/fpc-toolchain/targets.tsv"
  printf '#!/bin/sh\necho %s\n' "$1" > "$dir/lib/fpc/$ver/ppcx64"
  printf '#!/bin/sh\necho %s\n' "$1" > "$dir/bin/fpc"
  # fpcmkcfg -d ... -o FILE: write an empty config
  printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do [ "$1" = -o ] && : > "$2"; shift; done\n' > "$dir/bin/fpcmkcfg"
  chmod +x "$dir/lib/fpc/$ver/ppcx64" "$dir/bin/fpc" "$dir/bin/fpcmkcfg"
  echo "$dir"
}

install() { sh "$here/install.sh" --root "$root" --host test-host "$@" > "$work/out.txt" 2>&1 || { cat "$work/out.txt"; exit 1; }; }

expect_active() { # VERSION IDENTITY STEP
  got=$(readlink "$root/toolchains/$1" || echo none)
  if [ "$got" != "$2" ]; then echo "FAIL $3: toolchains/$1 -> $got, expected $2"; fails=$((fails + 1)); fi
  stray=$(find "$root/toolchains" -mindepth 1 -maxdepth 2 -name "$1.new")
  if [ -n "$stray" ]; then echo "FAIL $3: leftover $stray"; fails=$((fails + 1)); fi
  ran=$("$root/bin/fpc-$1" -iW)
  if [ "$ran" != "$2" ]; then echo "FAIL $3: fpc-$1 runs $ran, expected $2"; fails=$((fails + 1)); fi
}

install --from-dir "$(standin 3.3.1+1)"; expect_active 3.3.1 3.3.1+1 'first build of a version'
install --from-dir "$(standin 3.3.1+2)"; expect_active 3.3.1 3.3.1+2 'second build of the same version'
install --from-dir "$work/src/3.3.1+1"; expect_active 3.3.1 3.3.1+1 'the first build again'
install --no-activate --from-dir "$(standin 3.3.1+3)"; expect_active 3.3.1 3.3.1+1 'a build with --no-activate'

# An mv with neither -T nor -h (such as BusyBox's): install.sh falls back to removing the link and linking again.
mkdir "$work/shim"
printf '#!/bin/sh\ncase " $* " in *" -fT "*|*" -fh "*) exit 1 ;; esac\nexec %s "$@"\n' "$(command -v mv)" > "$work/shim/mv"
chmod +x "$work/shim/mv"
PATH=$work/shim:$PATH install --from-dir "$work/src/3.3.1+2"; expect_active 3.3.1 3.3.1+2 'without mv -T or -h'

if [ $fails -gt 0 ]; then echo "$fails activation check(s) failed"; exit 1; fi
echo "install.sh activation checks passed"
