#!/bin/sh
# check-release.sh VERSION DIR BUILD — a release is complete only if DIR has: a host archive for every TOOLCHAIN_HOSTS entry
# (.tar.xz, .zip for Windows), a units archive for every target some other host ships (.zip as well when a
# Windows host ships it), the source archives, and a SHA256SUMS that covers every file and matches.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
v=${1:?usage: check-release.sh VERSION DIR BUILD}; v=${v%%[-+]*}
vdir=$here/versions/$v; vdir_conf=$vdir/toolchain.conf
[ -f "$vdir_conf" ] || { echo "unknown version $1" >&2; exit 2; }
. "$vdir_conf"
dir=$2; tsv=$vdir/targets.tsv
tag="${FPC_VERSION}${FPC_UPSTREAM_MINORPATCH}-b${3:?usage: check-release.sh VERSION DIR BUILD}"
id="fpc-$tag"; missing=0
need() { [ -f "$dir/$1" ] || { echo "missing: $1"; missing=1; }; }
for h in $TOOLCHAIN_HOSTS; do
  case $h in *-win64) need "$id-$h.zip" ;; *) need "$id-$h.tar.xz" ;; esac
done
need "$id-source.tar.xz"; need "$id-source-patches.tar.xz"
need "binutils-2.42.tar.xz"   # source of the cross binutils shipped in cross/bin (GPL)
awk -F'\t' -v hosts=" $TOOLCHAIN_HOSTS " '$0 !~ /^#/ && $2!="excluded" {
    n=split($3,h,","); u=0; z=0
    for(i=1;i<=n;i++) if (h[i]!=$1 && index(hosts," " h[i] " ")) { u=1; if (h[i] ~ /-win64$/) z=1 }
    if (u) print $1, z }' "$tsv" |
while read -r t z; do
  [ -f "$dir/$id-units-$t.tar.xz" ] || echo "missing: $id-units-$t.tar.xz"
  [ "$z" = 1 ] && { [ -f "$dir/$id-units-$t.zip" ] || echo "missing: $id-units-$t.zip"; }
done | tee "$dir/.missing" >&2
[ -s "$dir/.missing" ] && missing=1; rm -f "$dir/.missing"
need SHA256SUMS
for f in "$dir"/*; do
  b=$(basename "$f"); [ "$b" = SHA256SUMS ] && continue
  grep -q "  $b\$" "$dir/SHA256SUMS" || { echo "not in SHA256SUMS: $b"; missing=1; }
done
(cd "$dir" && sha256sum -c --quiet SHA256SUMS) || missing=1
[ $missing = 0 ] && echo "release complete: $(ls "$dir" | wc -l | tr -d ' ') files"
exit $missing
