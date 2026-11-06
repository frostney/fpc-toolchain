#!/usr/bin/env bash
# smoke.sh — hello world for every target an installed toolchain has units for.
#
#   scripts/smoke.sh --fpc CMD --out DIR [--targets a,b,c] [--emulators]
#
#   --fpc CMD     compiler front-end to test, e.g. ~/.local/share/fpc-toolchains/bin/fpc-3.3.1
#   --out DIR     scratch dir; writes DIR/smoke.tsv: target, compile, link, run, detail
#   --targets     restrict to these targets (default: all units/<target> dirs of the build)
#   --emulators   run the binaries: native, qemu-<cpu>(-static), wine, wasmtime when available
# Linking is attempted for every target except embedded/freertos (board/SDK specific); failures of
# class `sdk` targets are expected and reported as such.
# On a Linux host, the row <host>:threads (selectable with --targets) builds a program with threadvars and a
# thread and a library with threadvars that it loads, and runs them: threadvars must be per thread, in the library
# too where the RTL keeps them in TLS sections (FPC_SECTION_THREADVARS).
set -uo pipefail

fpc='' out='' only='' emu=0
while [ $# -gt 0 ]; do
  case $1 in
    --fpc) fpc=$2; shift 2 ;; --out) out=$2; shift 2 ;;
    --targets) only=$2; shift 2 ;; --emulators) emu=1; shift ;;
    *) echo "unknown $1" >&2; exit 2 ;;
  esac
done
[ -n "$fpc" ] && [ -n "$out" ] || { echo "need --fpc and --out" >&2; exit 2; }
mkdir -p "$out"; out=$(cd "$out" && pwd)

# locate the build behind the front-end
ver=$($fpc -iV); tree=
case $fpc in
  */fpc-[0-9]*) tree=$(cd "$(dirname "$fpc")/../toolchains/$ver" && pwd -P) ;;
  *) tree=$(cd "$(dirname "$(command -v "${fpc%% *}")")/.." && pwd -P) ;;
esac
units=$tree/lib/fpc/$ver/units
[ -d "$units" ] || units=$tree/units
tsv=$tree/share/fpc-toolchain/targets.tsv
field() { awk -F'\t' -v t="$1" -v c="$2" '$0 !~ /^#/ && $1==t {print $c; exit}' "$tsv"; }

hostcpu=$($fpc -iSP); hostos=$($fpc -iSO)
cat > "$out/hellounit.pas" <<'EOF'
unit hellounit;
interface
function Greeting: string;
implementation
function Greeting: string; begin Greeting := 'hello'; end;
end.
EOF
cat > "$out/hello.pas" <<'EOF'
program hello;
begin
  writeln('hello from ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%}, ' fpc ', {$I %FPCVERSION%});
end.
EOF

printf 'target\tcompile\tlink\trun\tdetail\n' > "$out/smoke.tsv"
for td in "$units"/*/; do
  ud=$(basename "$td")
  # units can live in a directory other than <cpu>-<os> (UNITDIR= in targets.tsv, or the 8.3 os name)
  t=$(awk -F'\t' -v d="$ud" '$0 !~ /^#/ && (";" $5 ";") ~ (";UNITDIR=" d ";") {print $1; exit}' "$tsv")
  [ -n "$t" ] || case $ud in *-*) t=$ud ;; *) t=$(awk -F'\t' -v d="$ud" '$0 !~ /^#/ && $1 ~ ("-" d "$") {print $1; exit}' "$tsv") ;; esac
  [ -n "$t" ] || continue
  if [ -n "$only" ]; then case ",$only," in *",$t,"*) ;; *) continue ;; esac; fi
  cpu=${t%%-*}; os=${t#*-}; cls=$(field "$t" 2); margs=$(field "$t" 5)
  d=$out/$t; rm -rf "$d"; mkdir -p "$d"
  # compile inside the target's directory: some linker scripts name objects relative to it (mipsel-ps1)
  src=hello.pas
  opts=(-P"$cpu" -T"$os" -FE. -FU.)
  sub=$(echo "$margs" | tr ';' '\n' | sed -n 's/^SUBARCH=//p'); [ -n "$sub" ] && opts+=(-Cp"$sub")
  for o in $(echo "$margs" | tr ';' '\n' | sed -n 's/^CROSSOPT=//p'); do opts+=("$o"); done
  smoke=$(echo "$margs" | tr ';' '\n' | sed -n 's/^SMOKE=//p')
  if [ "$smoke" = unit ]; then src=hellounit.pas; nolinkunit=1; else nolinkunit=0
    for o in $smoke; do opts+=("$o"); done; fi
  cp "$out/hello.pas" "$out/hellounit.pas" "$d/"
  nolink=0
  case $os in embedded|freertos) nolink=1 ;; esac
  # compile + assemble only first (proves compiler, units and assembler)
  [ $nolinkunit = 1 ] && nolink=1
  if (cd "$d" && $fpc "${opts[@]}" -Cn "$src" > compile.log 2>&1); then c=ok; else c=FAIL; fi
  l=-; r=-; detail=
  if [ $c = ok ] && [ $nolink = 0 ]; then
    if (cd "$d" && $fpc "${opts[@]}" "$src" > link.log 2>&1); then l=ok
    else l=FAIL; [ "$cls" = sdk ] && l=needs-sdk; [ "$cls" = clang ] && case $os in darwin|ios|iphonesim) l=needs-sdk ;; esac
         detail=$(grep -m1 -iE 'error|fatal' "$d/link.log" | cut -c1-120); fi
  elif [ $c = FAIL ]; then
    detail=$(grep -m1 -iE 'error|fatal' "$d/compile.log" | cut -c1-120)
  fi
  if [ $emu = 1 ] && [ "$l" = ok ]; then
    exe=$(ls "$d"/hello "$d"/hello.exe "$d"/hello.wasm 2>/dev/null | head -n 1)
    runner=
    if [ "$cpu" = "$hostcpu" ] && [ "$os" = "$hostos" ]; then runner=
    else
      case $os in
        win64|win32) command -v wine >/dev/null 2>&1 && runner="wine" ; [ "$cpu" = aarch64 ] && runner= ;;
        wasip1) command -v wasmtime >/dev/null 2>&1 && runner="wasmtime run" ;;
        # wasmtime 49 dropped wasi-threads (-S threads), so wasip1threads binaries are linked, not run
        darwin) [ "$hostos" = darwin ] && { [ "$cpu" = "$hostcpu" ] || [ "$cpu" = x86_64 ]; } && runner="env" ;;   # x86_64 via Rosetta 2
        linux)
          q=$cpu
          case $cpu in x86_64) q=x86_64 ;; i386) q=i386 ;; powerpc) q=ppc ;; powerpc64) q=ppc64 ;; sparc) q=sparc32plus ;; esac
          for qc in qemu-$q-static qemu-$q; do command -v "$qc" >/dev/null 2>&1 && { runner=$qc; break; }; done ;;
      esac
    fi
    if [ -n "$runner" ] || { [ "$cpu" = "$hostcpu" ] && [ "$os" = "$hostos" ]; }; then
      to=; command -v timeout >/dev/null 2>&1 && to="timeout 120"
      if txt=$(cd "$d" && WINEDEBUG=-all $to $runner "$exe" 2>&1) && echo "$txt" | grep -q "hello from"; then
        r=ok; detail=$(echo "$txt" | grep -m1 "hello from")
      else r=FAIL; detail=$(echo "$txt" | tail -n 1 | cut -c1-120); fi
    else r=no-emulator; fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$t" "$c" "$l" "$r" "$detail" >> "$out/smoke.tsv"
  printf '%-24s compile=%-4s link=%-9s run=%-11s %s\n' "$t" "$c" "$l" "$r" "$detail" >&2
done

# threadvars in a program and in a library it loads, on the host itself (Linux; threads need libc); --targets
# selects it by its row name, <host>:threads
tv="$hostcpu-$hostos:threads"
if [ "$hostos" = linux ] && { [ -z "$only" ] || case ",$only," in *",$tv,"*) true ;; *) false ;; esac; }; then
  d=$out/threads; rm -rf "$d"; mkdir -p "$d"
  cat > "$d/tvlib.pas" <<'PAS'
library tvlib;
{$mode objfpc}
uses SysUtils;
threadvar Counter: Integer;
function Bump(N: Integer): Integer; cdecl;
var I: Integer;
begin
  for I := 1 to N do Inc(Counter);
  try raise Exception.Create('x'); except on E: Exception do Inc(Counter); end;
  Result := Counter;
end;
function SectionThreadvars: Integer; cdecl;
begin
  Result := {$ifdef FPC_SECTION_THREADVARS}1{$else}0{$endif};
end;
exports Bump, SectionThreadvars;
end.
PAS
  cat > "$d/tvprog.pas" <<'PAS'
program tvprog;
{$mode objfpc}
uses cthreads, SysUtils, Classes, dynlibs;
type
  TBump = function(N: Integer): Integer; cdecl;
  TFlag = function: Integer; cdecl;
  TWorker = class(TThread)
    Own, Lib: Integer;
    procedure Execute; override;
  end;
threadvar Counter: Integer;
var Bump: TBump; Flag: TFlag; H: TLibHandle; W: TWorker; M1, M2: Integer; Ok: Boolean;
procedure TWorker.Execute;
var I: Integer;
begin
  for I := 1 to 1000 do Inc(Counter);
  try raise Exception.Create('x'); except on E: Exception do Inc(Counter); end;
  Own := Counter;
  Lib := Bump(1000);
end;
begin
  Counter := 5;
  H := LoadLibrary('./libtvlib.so');
  if H = NilHandle then begin WriteLn('threads FAIL: ', GetLoadErrorStr); Halt(1); end;
  Bump := TBump(GetProcAddress(H, 'Bump'));
  Flag := TFlag(GetProcAddress(H, 'SectionThreadvars'));
  M1 := Bump(10); M2 := Bump(10);
  W := TWorker.Create(False); W.WaitFor;
  { a library's threadvars are per thread only where the RTL keeps them in TLS sections }
  Ok := (Counter = 5) and (W.Own = 1001) and (M1 = 11) and (M2 = 22) and ((Flag() = 0) or (W.Lib = 1001));
  if Ok then Write('threads ok') else Write('threads FAIL');
  WriteLn(': program ', Counter, '/', W.Own, ', library ', M1, '/', M2, '/', W.Lib,
    ', section threadvars ', {$ifdef FPC_SECTION_THREADVARS}'yes'{$else}'no'{$endif}, '/',
    BoolToStr(Flag() = 1, 'yes', 'no'));
  if not Ok then Halt(1);
end.
PAS
  t=$tv; l=-; r=-; detail=
  if (cd "$d" && $fpc tvlib.pas > lib.log 2>&1 && $fpc tvprog.pas > prog.log 2>&1); then
    c=ok; l=ok
    to=; command -v timeout >/dev/null 2>&1 && to="timeout 120"
    if txt=$(cd "$d" && $to ./tvprog 2>&1) && echo "$txt" | grep -q "threads ok"; then r=ok; else r=FAIL; fi
    detail=$(echo "$txt" | tail -n 1 | cut -c1-120)
  else
    c=FAIL; detail=$(cat "$d/lib.log" "$d/prog.log" 2>/dev/null | grep -m1 -iE 'error|fatal' | cut -c1-120)
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$t" "$c" "$l" "$r" "$detail" >> "$out/smoke.tsv"
  printf '%-24s compile=%-4s link=%-9s run=%-11s %s\n' "$t" "$c" "$l" "$r" "$detail" >&2
fi
