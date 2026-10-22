#!/bin/sh
# binutils-packages.sh — read binutils prefixes (stdin, one per line, e.g. aarch64-linux-gnu-) and print the
# Debian/Ubuntu package names that provide them and exist for this machine (skips the host's own binutils).
host=$(dpkg --print-architecture 2>/dev/null)
while read -r p; do
  t=${p%-}
  case $t in
    i586-pc-msdosdjgpp) pkg=binutils-djgpp ;;
    xtensa-lx106-elf) pkg=binutils-xtensa-lx106 ;;
    avr) pkg=binutils-avr ;;
    z80-unknown-coff) pkg=binutils-z80 ;;
    x86_64-linux-gnu) [ "$host" = amd64 ] && continue; pkg=binutils-x86-64-linux-gnu ;;
    aarch64-linux-gnu) [ "$host" = arm64 ] && continue; pkg=binutils-aarch64-linux-gnu ;;
    *) pkg=binutils-$(echo "$t" | tr '_' '-') ;;
  esac
  if apt-cache show "$pkg" >/dev/null 2>&1; then echo "$pkg"; else echo "binutils-packages: no $pkg for $host" >&2; fi
done | sort -u
