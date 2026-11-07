# Patches

Applied in name order on FPC `main` at `fa51767875` (2026-10-14). They fix the wrong-code, internal-error and
RTL bugs the GocciaScript compiler bug hunt found, carry the wasm32 work, and (0079) give a library or package
the global-dynamic TLS model that a compiler with section threadvars otherwise used only with `-Cg`.
0080-0113 are the x86_64 code generation work of the November 2026 benchmark loop against gcc (register
variables with exception handling, loop and induction variable optimisations, inlining at -O3, the SLP
vectoriser at -O4 with its `SLP` optimizer switch, peephole rules), together with the wrong-code bugs it found
in the base (constant propagation inside an assignment, inline routines with try, procvars from inline
routines, record promotion with exceptions, x86 peephole aliasing, flags of float compares) and in its own work.
The fixes are not restricted to a target. The new optimisations were validated on x86_64 only, so they are
compiled for x86_64 only. Register variables with exception handling are also off on win64 (SEH) and in compilers
built for psABI exception handling (`-dpsabieh`, LLVM), whose unwinding they were not checked against.

0080 changes behaviour outside the optimiser: a program without a mode directive now inlines `inline` routines, as
`{$mode fpc}` already did. 0081 fixes a defect in the base peephole optimiser that the base itself never triggered
(tests/test/opt/tpeepalias1.pp passes there too) but the later register allocation did. Every other patch that
fixes wrong code carries a test under `tests/test`. 0110's test is tests/test/opt/tslp1.pp, because only the SLP
vectoriser creates loads after the DFA. 0114-0115 fix anonymous functions nested in anonymous functions of the main
block or of initialization/finalization sections (gitlab #40316) and anonymous functions in both sections of a
unit. 0116 completes 0080-0113 after review: SLP pointer provenance, loads hoisted only when every iteration
evaluates them (both with tests in tslp1 and tslp2) and the target gating above. `toolchain.conf` pins the
resulting tree (`FPC_EXPECT_TREE`), so the build fails if the base or the series drifts.

To take a new series from a branch built on the same base:

    scripts/update-series.sh 3.3.1 <git-url>#<branch>

It rewrites `patches/`, updates `FPC_EXPECT_TREE` and writes `SERIES_AUTHOR` into our own patches. Review the
diff, commit, and tag the next build (`3.3.1-b<N+1>`).
