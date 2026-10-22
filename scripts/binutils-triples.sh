#!/usr/bin/env bash
# binutils-triples.sh VERSION HOST — the GNU binutils target triples a host's archive ships: one per binutils
# prefix of the targets that host ships, without the host's own (native) toolchain.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/scripts/lib.sh"
load_version "${1:?usage: binutils-triples.sh VERSION HOST}"
host=${2:?usage: binutils-triples.sh VERSION HOST}
case $host in x86_64-linux) native=x86_64-linux-gnu- ;; aarch64-linux) native=aarch64-linux-gnu- ;; *) native= ;; esac
awk -F'\t' -v h="$host" -v n="$native" '$0 !~ /^#/ && ($2=="binutils" || $2=="sdk") && $4 ~ /-$/ && $4 != n \
  && (","$3",") ~ (","h",") && $1 != h { sub(/-$/, "", $4); print $4 }' "$tsv" | sort -u
