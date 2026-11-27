#!/bin/sh
# check-install-activation.sh — install.sh makes each new build the active one for its version.
#
#   check-install-activation.sh
#
# Installs stand-in builds (shell scripts that print their identity, no compiler) with --from-dir into a
# temporary root: two builds of one version in turn, the first again, one with --no-activate, and one with
# an mv that has neither -T nor -h.
# After each, toolchains/<version> must point at the expected build, nothing may be left beside it or
# inside another build, and fpc-<version> must run that build. The link must also have been renamed over,
# never removed or linked onto, except with that last mv: rm and ln on PATH log what install.sh removes and
# where it links. Last, a build whose compiler reports another identity, and a reinstall of the active build
# whose front end does not run, must fail to install and leave the active build as it was. Needs no network.
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

# rm that logs "rm PATH" for each path it is given, and ln that logs "ln TARGET" for the link it makes
mkdir "$work/watch"
printf '#!/bin/sh\nfor a in "$@"; do printf "rm %%s\\n" "$a"; done >> "%s"\nexec %s "$@"\n' \
  "$work/watch.log" "$(command -v rm)" > "$work/watch/rm"
printf '#!/bin/sh\nfor a in "$@"; do last=$a; done\nprintf "ln %%s\\n" "$last" >> "%s"\nexec %s "$@"\n' \
  "$work/watch.log" "$(command -v ln)" > "$work/watch/ln"
chmod +x "$work/watch/rm" "$work/watch/ln"

install() {
  : > "$work/watch.log"
  PATH=$work/watch:$PATH sh "$here/install.sh" --root "$root" --host test-host "$@" > "$work/out.txt" 2>&1 \
    || { cat "$work/out.txt"; exit 1; }
}

expect_active() { # VERSION IDENTITY STEP [relinked: the link was removed and linked again]
  got=$(readlink "$root/toolchains/$1" || echo none)
  if [ "$got" != "$2" ]; then echo "FAIL $3: toolchains/$1 -> $got, expected $2"; fails=$((fails + 1)); fi
  stray=$(find "$root/toolchains" -mindepth 1 -maxdepth 2 -name "$1.new")
  if [ -n "$stray" ]; then echo "FAIL $3: leftover $stray"; fails=$((fails + 1)); fi
  ran=$("$root/bin/fpc-$1" -iW 2>&1) || ran="a failure (exit $?)"
  if [ "$ran" != "$2" ]; then echo "FAIL $3: fpc-$1 runs $ran, expected $2"; fails=$((fails + 1)); fi
  relinked=no
  grep -qxF -e "rm $root/toolchains/$1" -e "ln $root/toolchains/$1" "$work/watch.log" && relinked=yes
  if [ "$relinked" = yes ] && [ "${4:-}" != relinked ]; then
    echo "FAIL $3: toolchains/$1 was removed or linked onto, not renamed over"; fails=$((fails + 1))
  elif [ "$relinked" = no ] && [ "${4:-}" = relinked ]; then
    echo "FAIL $3: toolchains/$1 was not linked again by the fallback"; fails=$((fails + 1))
  fi
}

install --from-dir "$(standin 3.3.1+1)"; expect_active 3.3.1 3.3.1+1 'first build of a version'
install --from-dir "$(standin 3.3.1+2)"; expect_active 3.3.1 3.3.1+2 'second build of the same version'
install --from-dir "$work/src/3.3.1+1"; expect_active 3.3.1 3.3.1+1 'the first build again'
install --no-activate --from-dir "$(standin 3.3.1+3)"; expect_active 3.3.1 3.3.1+1 'a build with --no-activate'

# An mv with neither -T nor -h, such as OpenBSD's or BusyBox 1.31's: install.sh falls back to removing
# the link and linking again.
mkdir "$work/shim"
printf '#!/bin/sh\ncase " $* " in *" -fT "*|*" -fh "*) exit 1 ;; esac\nexec %s "$@"\n' "$(command -v mv)" > "$work/shim/mv"
chmod +x "$work/shim/mv"
PATH=$work/shim:$PATH install --from-dir "$work/src/3.3.1+2"; expect_active 3.3.1 3.3.1+2 'without mv -T or -h' relinked

# A build whose compiler reports another identity: install.sh fails and 3.3.1+2 stays active.
bad=$(standin 3.3.1+4); printf '#!/bin/sh\necho 3.3.1+0\n' > "$bad/lib/fpc/3.3.1/ppcx64"
: > "$work/watch.log"
if sh "$here/install.sh" --root "$root" --host test-host --from-dir "$bad" > "$work/out.txt" 2>&1; then
  echo "FAIL a build that reports another identity: install.sh exited 0"; fails=$((fails + 1))
fi
expect_active 3.3.1 3.3.1+2 'a build that reports another identity'

# A reinstall of the active 3.3.1+2 whose front end does not run: install.sh fails before it replaces the
# active build's directory, so fpc-3.3.1 still runs the original.
same=$work/src/same/3.3.1+2; mkdir -p "$work/src/same"; cp -R "$work/src/3.3.1+2" "$same"
printf '#!/bin/sh\nexit 1\n' > "$same/bin/fpc"
: > "$work/watch.log"
if sh "$here/install.sh" --root "$root" --host test-host --from-dir "$same" > "$work/out.txt" 2>&1; then
  echo "FAIL a reinstall of the active build that does not run: install.sh exited 0"; fails=$((fails + 1))
fi
expect_active 3.3.1 3.3.1+2 'a reinstall of the active build that does not run'
if [ -e "$root/toolchains/3.3.1+2.new" ]; then echo "FAIL a rejected build left 3.3.1+2.new"; fails=$((fails + 1)); fi

if [ $fails -gt 0 ]; then echo "$fails activation check(s) failed"; exit 1; fi
echo "install.sh activation checks passed"
