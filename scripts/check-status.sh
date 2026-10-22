#!/bin/sh
# check-status.sh TARGETS.tsv CROSS-STATUS.tsv — fail if a target that targets.tsv expects to build did not.
# (Targets that cannot be built from this source are `excluded` in targets.tsv with the reason.)
set -eu
bad=$(awk -F'\t' '$3=="FAIL" {print $1}' "$2" | sort -u)
[ -z "$bad" ] && { echo "all cross targets built"; exit 0; }
echo "cross targets that failed to build:"; echo "$bad" | sed 's/^/  /'
exit 1
