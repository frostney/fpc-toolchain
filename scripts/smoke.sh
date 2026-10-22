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
