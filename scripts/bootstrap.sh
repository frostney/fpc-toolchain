#!/usr/bin/env bash
# bootstrap.sh DIR — fetch the official FPC 3.2.2 release for this build host into DIR (sha256-pinned)
# and print the path of its native compiler. Only the first compiler stage is built with it; everything
# shipped is compiled by the freshly built compiler.
set -euo pipefail
dir=${1:?usage: bootstrap.sh DIR}
mkdir -p "$dir"; dir=$(cd "$dir" && pwd)
sf=https://downloads.sourceforge.net/project/freepascal
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)  f=fpc-3.2.2.x86_64-linux.tar;  u="$sf/Linux/3.2.2/$f"; sum=5adac308a5534b6a76446d8311fc340747cbb7edeaacfe6b651493ff3fe31e83; ppc=ppcx64 ;;
  Linux-aarch64) f=fpc-3.2.2.aarch64-linux.tar; u="$sf/Linux/3.2.2/$f"; sum=b39470f9b6b5b82f50fc8680a5da37d2834f2129c65c24c5628a80894d565451; ppc=ppca64 ;;
  Darwin-arm64)  f=fpc-3.2.2.intelarm64-macosx.dmg; u="$sf/Mac%20OS%20X/3.2.2/$f"; sum=05d4510c8c887e3c68de20272abf62171aa5b2ef1eba6bce25e4c0bc41ba8b7d; ppc=ppca64 ;;
  Darwin-x86_64) f=fpc-3.2.2.intelarm64-macosx.dmg; u="$sf/Mac%20OS%20X/3.2.2/$f"; sum=05d4510c8c887e3c68de20272abf62171aa5b2ef1eba6bce25e4c0bc41ba8b7d; ppc=ppcx64 ;;
  *) echo "bootstrap.sh: no pinned bootstrap for $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac
if [ ! -x "$dir/$ppc" ]; then
  [ -s "$dir/$f" ] || curl -fsSL --retry 3 -o "$dir/$f" "$u"
  got=$( (sha256sum "$dir/$f" 2>/dev/null || shasum -a 256 "$dir/$f") | cut -d' ' -f1)
  [ "$got" = "$sum" ] || { echo "bootstrap.sh: sha256 mismatch for $f: $got" >&2; exit 1; }
  case $f in
    *.tar)
      mkdir -p "$dir/x"; tar -xf "$dir/$f" -C "$dir/x"
      tar -xf "$dir"/x/*/binary.*.tar -C "$dir/x"
      tar -xzf "$dir"/x/base.*.tar.gz -C "$dir/x" "lib/fpc/3.2.2/$ppc"
      cp "$dir/x/lib/fpc/3.2.2/$ppc" "$dir/$ppc" ;;
    *.dmg)
      mnt=$(mktemp -d); hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mnt" "$dir/$f"
      pkg=$(find "$mnt" -name '*.pkg' -type f | head -n 1)   # flat pkg inside the .mpkg bundle
      [ -n "$pkg" ] || { echo "bootstrap.sh: no .pkg in $f" >&2; exit 1; }
      rm -rf "$dir/pkg"; pkgutil --expand-full "$pkg" "$dir/pkg"; hdiutil detach -quiet "$mnt"
      cp "$(find "$dir/pkg" -path "*lib/fpc/3.2.2/$ppc" -type f | head -n 1)" "$dir/$ppc" ;;
  esac
  rm -rf "$dir/x" "$dir/pkg"; chmod +x "$dir/$ppc"
fi
"$dir/$ppc" -iV >/dev/null
echo "$dir/$ppc"
