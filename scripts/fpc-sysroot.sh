#!/bin/sh
# fpc-sysroot.sh TARGET DIR [EXTRA_PACKAGE...] — fetch a glibc sysroot for cross-linking programs that use
# libc (cthreads, C libraries) from Ubuntu 24.04 (noble) packages, and print the FPC options to use it.
#
#   fpc-sysroot.sh aarch64-linux ~/.local/share/fpc-sysroots/aarch64-linux libicu74 libstdc++6
#   fpc-3.3.1 -Paarch64 -Tlinux $(cat ~/.local/share/fpc-sysroots/aarch64-linux/fpc-options) app.pas
#
# Plain FPC programs on Linux need no sysroot (the RTL makes system calls itself). Sysroots are fetched,
# never shipped: they are distribution packages under their own licences. Every .deb is checked against the
# SHA256 in the distribution's Packages index (HTTPS). Needs curl, xz, ar and tar (no dpkg, no root).
#
# Targets: x86_64-linux (amd64), i386-linux (i386), aarch64-linux (arm64), arm-linux (armhf, use FPC's
# -CaEABIHF -CfVFPV3 for hard-float), riscv64-linux (riscv64). Other FPC Linux targets have no Ubuntu port.
set -eu
target=${1:?usage: fpc-sysroot.sh TARGET DIR [EXTRA_PACKAGE...]}; dir=${2:?usage: fpc-sysroot.sh TARGET DIR}
shift 2
suite=${FPC_SYSROOT_SUITE:-noble}
case $target in
  x86_64-linux)  arch=amd64;   triplet=x86_64-linux-gnu;     mirror=https://archive.ubuntu.com/ubuntu ;;
  i386-linux)    arch=i386;    triplet=i386-linux-gnu;       mirror=https://archive.ubuntu.com/ubuntu ;;
  aarch64-linux) arch=arm64;   triplet=aarch64-linux-gnu;    mirror=https://ports.ubuntu.com/ubuntu-ports ;;
  arm-linux)     arch=armhf;   triplet=arm-linux-gnueabihf;  mirror=https://ports.ubuntu.com/ubuntu-ports ;;
  riscv64-linux) arch=riscv64; triplet=riscv64-linux-gnu;    mirror=https://ports.ubuntu.com/ubuntu-ports ;;
  *) echo "fpc-sysroot.sh: no Ubuntu port for $target" >&2; exit 1 ;;
esac
mirror=${FPC_SYSROOT_MIRROR:-$mirror}
mkdir -p "$dir/.debs"; dir=$(cd "$dir" && pwd)
idx=$dir/.debs/Packages
: > "$idx"
for s in "$suite" "$suite-updates" "$suite-security"; do
  for c in main universe; do
    curl -fsSL "$mirror/dists/$s/$c/binary-$arch/Packages.xz" 2>/dev/null | xz -dc >> "$idx" || true
  done
done
[ -s "$idx" ] || { echo "fpc-sysroot.sh: no package index from $mirror" >&2; exit 1; }

# newest Filename/SHA256 of a package (later suites in the index win)
lookup() { awk -v p="$1" '/^Package: /{pk=$2} /^Filename: /{if(pk==p)f=$2} /^SHA256: /{if(pk==p)h=$2} END{if(f!="")print f, h}' "$idx"; }

pkgs="libc6 libc6-dev libgcc-s1 libcrypt1 libcrypt-dev $*"
gccdev=$(awk '/^Package: libgcc-[0-9]+-dev$/{print $2}' "$idx" | sort -t- -k2 -n | tail -n 1)
[ -n "$gccdev" ] && pkgs="$pkgs $gccdev"
for p in $pkgs; do
  set -- $(lookup "$p")
  [ $# = 2 ] || { echo "fpc-sysroot.sh: $p not found for $arch" >&2; exit 1; }
  deb=$dir/.debs/$(basename "$1")
  [ -s "$deb" ] || curl -fsSL -o "$deb" "$mirror/$1"
  got=$( (sha256sum "$deb" 2>/dev/null || shasum -a 256 "$deb") | cut -d' ' -f1)
  [ "$got" = "$2" ] || { echo "fpc-sysroot.sh: sha256 mismatch for $deb" >&2; exit 1; }
  ( cd "$dir/.debs" && rm -f data.tar.* control.tar.* debian-binary && ar x "$deb" \
    && for d in data.tar.*; do case $d in *.xz) xz -dc "$d" ;; *.zst) zstd -dc "$d" ;; *.gz) gzip -dc "$d" ;; esac; done \
       | tar -xf - -C "$dir" && rm -f data.tar.* control.tar.* debian-binary )
  echo "  $p ($(basename "$1"))" >&2
done
# merged-/usr layout: the libc linker scripts name /lib/... and the dynamic linker lives in /lib
[ -e "$dir/lib" ] || ln -s usr/lib "$dir/lib"
[ "$arch" = amd64 ] && [ ! -e "$dir/lib64" ] && ln -s usr/lib64 "$dir/lib64" 2>/dev/null || true
gccdir=$(ls -d "$dir/usr/lib/gcc/$triplet"/* 2>/dev/null | sort -V | tail -n 1)   # crtbegin.o/crtend.o
printf -- '-XR%s -Fl%s/usr/lib/%s%s -k--sysroot=%s\n' "$dir" "$dir" "$triplet" "${gccdir:+ -Fl$gccdir}" "$dir" > "$dir/fpc-options"
echo "sysroot $target -> $dir"
echo "FPC options: $(cat "$dir/fpc-options")"
echo "run under qemu-user with: qemu-<cpu> -L $dir ./program"
