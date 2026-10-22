#!/usr/bin/env bash
# build-binutils.sh [--host TRIPLE] OUT TRIPLE... — build GNU binutils (as, ld, ar, objcopy, strip, ...) from source for each target
# triple into OUT/bin as <triple>-<tool>. Used where no packaged cross binutils exist (macOS has no
# aarch64-linux-gnu binutils). The source tarball is sha256-pinned and goes into the release (GPL).
#
#   scripts/build-binutils.sh /tmp/xb aarch64-linux-gnu x86_64-linux-gnu
#   scripts/build-binutils.sh --host x86_64-w64-mingw32 /tmp/xb-win aarch64-linux-gnu   (Windows exes, built on Linux)
#   BINUTILS_SRC=/path/to/binutils-2.42.tar.xz to use a local copy.
set -euo pipefail
BINUTILS_VERSION=2.42
BINUTILS_SHA256=f6e4d41fd5fc778b06b7891457b3620da5ecea1006c6a4a41ae998109f85a800
hostopt=()
# macOS: link the SDK's zlib instead of building the bundled copy
case $(uname -s) in Darwin) hostopt+=(--with-system-zlib) ;; esac
if [ "${1:-}" = --host ]; then hostopt+=(--host="$2" --build="$(uname -m)-linux-gnu"); export LDFLAGS="${LDFLAGS:-} -static -s"; shift 2; fi
out=${1:?usage: build-binutils.sh [--host TRIPLE] OUT TRIPLE...}; shift
[ $# -gt 0 ] || { echo "build-binutils.sh: no triples" >&2; exit 2; }
mkdir -p "$out"; out=$(cd "$out" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# the source tarball lives in OUT/src (cached with the tools); fetched only when a triple must be built,
# or always with BINUTILS_FETCH_SOURCE=1 (the release attaches it)
missing=; for t in "$@"; do [ -e "$out/bin/$t-as" ] || [ -e "$out/bin/$t-as.exe" ] || missing=1; done
tarball=${BINUTILS_SRC:-$out/src/binutils-$BINUTILS_VERSION.tar.xz}
if [ -n "$missing" ] || [ -n "${BINUTILS_FETCH_SOURCE:-}" ]; then
  mkdir -p "$out/src"
  for m in https://ftpmirror.gnu.org/gnu/binutils https://ftp.gnu.org/gnu/binutils \
           https://mirrors.kernel.org/gnu/binutils https://sourceware.org/pub/binutils/releases; do
    [ -s "$tarball" ] && break
    curl -fsSL --connect-timeout 20 --retry 2 -o "$tarball.part" "$m/binutils-$BINUTILS_VERSION.tar.xz" \
      && mv "$tarball.part" "$tarball" || { rm -f "$tarball.part"; echo "binutils source: $m failed" >&2; }
  done
  [ -s "$tarball" ] || { echo "build-binutils.sh: cannot download binutils-$BINUTILS_VERSION.tar.xz" >&2; exit 1; }
  got=$( (sha256sum "$tarball" 2>/dev/null || shasum -a 256 "$tarball") | cut -d' ' -f1)
  [ "$got" = "$BINUTILS_SHA256" ] || { echo "build-binutils.sh: sha256 mismatch for $tarball" >&2; exit 1; }
fi
[ -n "$missing" ] && xz -dc "$tarball" | tar -xf - -C "$work"
jobs=$( (nproc || sysctl -n hw.ncpu) 2>/dev/null || echo 4)
for t in "$@"; do
  if [ -e "$out/bin/$t-as" ] || [ -e "$out/bin/$t-as.exe" ]; then echo "binutils $t: cached"; continue; fi
  echo "binutils $t: building"
  b=$work/build-$t; mkdir -p "$b"
  (cd "$b" && "$work/binutils-$BINUTILS_VERSION/configure" ${hostopt[@]+"${hostopt[@]}"} --target="$t" --prefix="$out" --program-prefix="$t-" \
     --disable-nls --disable-werror --disable-gdb --disable-gdbserver --disable-sim --disable-gprof \
     --disable-gprofng --disable-libctf --disable-plugins --enable-deterministic-archives MAKEINFO=true \
     > "$out/configure-$t.log" 2>&1 \
   && make -j"$jobs" MAKEINFO=true all-gas all-ld all-binutils > "$out/make-$t.log" 2>&1 \
   && make MAKEINFO=true install-strip-gas install-strip-ld install-strip-binutils >> "$out/make-$t.log" 2>&1) \
   || { echo "binutils $t: failed; the first errors (serial make):"
        (cd "$b" && make -k MAKEINFO=true all-gas all-ld all-binutils > "$out/make1-$t.log" 2>&1) || true
        grep -n -E -i '(error|undefined|fatal)[: ]' "$out/make1-$t.log" | head -n 40
        tail -n 15 "$out/make1-$t.log"; exit 1; }
  rm -rf "$b"
done
# only the prefixed tools are shipped; drop the target directories and docs
rm -rf "${out:?}/share" "${out:?}/lib" "${out:?}/include"
for d in "$out"/*-*/; do [ -d "$d" ] && [ "$(basename "$d")" != bin ] && rm -rf "$d"; done
ls "$out/bin"
