#!/bin/sh
# check-smoke.sh TARGETS.tsv SMOKE.tsv [HOST] — fail on a compile or run failure, on a link failure of an
# internal or binutils target (their tools ship with the build), on a Darwin target that doesn't link on a macOS
# HOST, or when a target in SMOKE_REQUIRE_RUN (toolchain.conf, or the environment) didn't run. sdk targets
# and Darwin targets elsewhere may fail to link: their SDK (NDK, Apple, vendor) isn't on the runner.
set -eu
req=${SMOKE_REQUIRE_RUN-$(sed -n 's/^SMOKE_REQUIRE_RUN=//p' "$(dirname "$1")/toolchain.conf")}
host=${3:-}
awk -F'\t' -v req=",$req," -v host="$host" 'NR==FNR { if ($0 !~ /^#/) cls[$1]=$2; next }
  FNR>1 && ($2=="FAIL" || $4=="FAIL" || ($3=="FAIL" && (cls[$1]=="internal" || cls[$1]=="binutils"))) { print; bad=1 }
  FNR>1 && host ~ /-darwin$/ && $1 ~ /-darwin$/ && $3!="ok" { print "Darwin target must link on macOS:", $0; bad=1 }
  FNR>1 && index(req, "," $1 ",") && $4!="ok" { print "required run missing:", $0; bad=1 }
  END { exit bad }' "$1" "$2" && echo "smoke ok"
