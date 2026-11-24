# Patches

Applied in name order on FPC `main` at `fa51767875` (2026-10-14). They fix the wrong-code, internal-error and RTL
bugs the GocciaScript compiler bug hunt found, carry the wasm32 work, and (0079) give a library or package the
global-dynamic TLS model that a compiler with section threadvars otherwise used only with `-Cg`. 0080-0113 are the
x86_64 code generation work of the November 2026 benchmark loop against gcc (register variables with exception
handling, loop and induction variable optimisations, inlining at -O3, the SLP vectoriser at -O4 with its `SLP`
optimizer switch, peephole rules), together with the wrong-code bugs it found in the base (constant propagation
inside an assignment, inline routines with try, procvars from inline routines, record promotion with exceptions,
x86 peephole aliasing, flags of float compares) and in its own work. The fixes are not restricted to a target. The
new optimisations were validated on x86_64 only, so they are compiled for x86_64 only, with two exceptions: 0091
makes Math's `IsNan` and `IsInfinite` for Double inline bit tests on every target whose Double is not word-swapped,
and 0111 moves 128-bit vector values (`OS_M128`) with `movaps`/`movups` on i386 too (the same bits as before).
Register variables with exception handling are also off on win64 (SEH) and in compilers built for psABI exception
handling (`-dpsabieh`, LLVM), whose unwinding they were not checked against.

0080 changes behaviour outside the optimiser: a program without a mode directive now inlines `inline` routines, as
`{$mode fpc}` already did. 0081 fixes a defect in the base peephole optimiser that the base itself never triggered
(tests/test/opt/tpeepalias1.pp passes there too) but the later register allocation did. 0110 is defensive since
0113, which gives the loads that the vectoriser copies their DFA index; before 0113, tests/test/opt/tslp1.pp failed
without it. Every other patch that fixes wrong code carries a test under `tests/test`. 0114-0115 fix anonymous
functions nested in anonymous functions of the main block or of initialization/finalization sections (gitlab
#40316) and anonymous functions in both sections of a unit. 0116-0118 complete 0080-0113 after review: SLP pointer
provenance, the target gating above, and loads that move before a loop only when nothing can tell (not past an
inline routine that writes them, a label, or a statement of the first iteration that can raise an exception first,
such as a division or a statement with overflow or range checks). 0119 lets the node DFA of 0103 finish: life sets
are computed in copies, never in a node's own set, so a variable that an `if` condition defines and an exception
handler reads no longer changes on every pass (a function result passed as an `out` parameter in a `try..finally`
hung the compiler at `-O2 -OoDFA`, `-O3` and `-O4`), and a set that grows is always seen as a change. 0120-0121 fix two x86 peephole bugs
of trunk itself, not reported upstream yet: 0120 (`CMovMov2CMov` at `-O3`: a CMOV wrote its source register while
instructions before the MOV it replaced still used it; 0089 made it reachable in procedures with exception
handling) and 0121 (`LeaOp2Op` at `-O1` dropped the `@tpoff` relocation of a threadvar, which only the section
threadvars of this build reach). 0122 fixes 0107: a register that a branch placed out of line used first (the
counter of a loop in a raise or halt branch near the start of a routine, which a later loop uses again) had its
live range start in that code, after the routine's end, so the register allocator gave its register to other values
everywhere before (wrong code at `-O2` and above). 0123 fixes trunk's internal x86 assembler: it took an
instruction's segment override only from `segprefix`, which `loadref` sets, and an optimisation that puts a reference
in place without it (MovLea2Add folds `mov %fs:B@tpoff,%edx; lea (%edx,%eax),%eax` into an `add`) lost the `%fs` of
a section threadvar, so adding two threadvars at `-O1` read the second at an absolute address (runtime error 216).
0124 is upstream's a7b0e8a265 (trunk #41970, after this base): when an incremental compile recompiles a used unit,
the symbol tables already loaded from `.ppu` files are dereferenced again instead of keeping pointers into the
freed old definitions, which made such a compile fail with "Compilation raised exception internally" or a type
error between unrelated types. The two test programs the upstream commit adds as built binaries are left out.
0125 is upstream's follow-up 82b9e12b93, which ignores those programs in the test directories. 0126 completes 0124
for class helpers: the alias procsym a class helper's implementation makes for each of its methods is not stored,
so it has no dereference data, and the second dereference 0124 runs stopped with internal error 200611031; such an
alias now only clears its list, which the helper's implementation dereference fills again
(`tests/tppu/reloadhelper`).
0127 makes the rest of that second dereference leave what one leaves: a generic constraint's interface list is
rebuilt instead of appended to, a copied enum, record or object def and an overriding indexed property keep their
counted reference to the shared symtable instead of taking another each time, and a class helper's alias gets each
method once (`tests/tppu/reloadcopy`).
0128 limits that second dereference to the defs and syms the table had when it got its dereference data: one the
first dereference added (the array type of a constant's data, such as `#$0100#$0101`) has none, and dereferencing
it stopped with internal error 200306067.
0129 narrows 0112's hoisting of loop-invariant loads (`-O4`, under `SLP`) to values loaded whole: ordinals,
floats, pointers, enumerations, class references, procedure variables, implicit-pointer object types (classes and
interfaces, COM, CORBA and dispatch) and SSE vectors. A field
that is an array or a record went into a temp of its declared size, and the loop then indexed the temp, so the
variable-length idiom (a last field declared `array[0..0]`, indexed past it) read the stack beyond the temp
(`tests/test/opt/tslp4.pp`). 0130 makes that test's record case fail on its own when only record fields are
moved again (it accumulated into the function result, a store that kept every load in the loop).
0131 is for aarch64 only: the peephole optimizer turns a test of one bit (`tst`, or `and` plus `cmp`) and a
`b.eq` or `b.ne` into `tbz` or `tbnz`, which reach only +-32 KiB, without knowing how far the label is, so in a
larger procedure the assembler refused one ("conditional branch out of range"). After the optimizer, each one whose
label is more than 7000 instructions away becomes the opposite test over an unconditional `b`, which reaches +-128
MiB (`tests/test/opt/ttbz1.pp`).
`toolchain.conf` pins the resulting tree
(`FPC_EXPECT_TREE`), so the build fails if the base or the series drifts.

To take a new series from a branch built on the same base:

    scripts/update-series.sh 3.3.1 <git-url>#<branch>

It rewrites `patches/`, updates `FPC_EXPECT_TREE` and writes `SERIES_AUTHOR` into our own patches. Review the
diff, commit, and tag the next build (`3.3.1-b<N+1>`).
