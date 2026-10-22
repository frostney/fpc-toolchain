#!/bin/sh
# check-smoke.sh TARGETS.tsv SMOKE.tsv — fail on a compile or run failure, on a link failure of a target whose
# class says it links with what the runner has (internal, binutils), or when a target listed in
# SMOKE_REQUIRE_RUN (toolchain.conf, or the environment) did not run. clang/sdk targets may fail to link
# (Apple SDK, NDK, vendor sysroots are not on the runner).
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
req=${SMOKE_REQUIRE_RUN-$(sed -n 's/^SMOKE_REQUIRE_RUN=//p' "$here/toolchain.conf")}
awk -F'\t' -v req=",$req," 'NR==FNR { if ($0 !~ /^#/) cls[$1]=$2; next }
  FNR>1 && ($2=="FAIL" || $4=="FAIL" || ($3=="FAIL" && (cls[$1]=="internal" || cls[$1]=="binutils"))) { print; bad=1 }
  FNR>1 && index(req, "," $1 ",") && $4!="ok" { print "required run missing:", $0; bad=1 }
  END { exit bad }' "$1" "$2" && echo "smoke ok"
