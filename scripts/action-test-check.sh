#!/usr/bin/env bash
# action-test-check.sh VERSION IDENTITY CROSS — after the action: fpc on PATH is the installed build, hello
# world compiles and runs natively, and links for the cross target.
set -euo pipefail
v=$1 id=$2 cross=$3
got=$(fpc -iW | tr -d '\r'); [ "$got" = "$id" ] || { echo "fpc on PATH is $got, expected $id"; exit 1; }
case $RUNNER_OS in Windows) fe="fpc-$v.cmd" ;; *) fe="fpc-$v" ;; esac
command -v "$fe" >/dev/null || { echo "$fe not on PATH"; exit 1; }
d=$(mktemp -d); cd "$d"
printf "program hello; begin writeln('hello from ', {\$I %%FPCTARGETCPU%%}, '-', {\$I %%FPCTARGETOS%%}); end.\n" > hello.pas
fpc hello.pas
out=$(./hello | tr -d '\r'); echo "$out"; case $out in "hello from "*) ;; *) exit 1 ;; esac
if [ -n "$cross" ]; then
  mkdir x; fpc -P"${cross%%-*}" -T"${cross#*-}" -FEx -FUx hello.pas
  ls -la x/hello*
  case $cross in wasm32-wasip1) command -v wasmtime >/dev/null && wasmtime run x/hello.wasm || true ;; esac
fi
echo "action ok: $got, cross $cross"
