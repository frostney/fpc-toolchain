# Patches

Applied in name order on FPC `main` at `fa51767875` (2026-10-14). They fix the wrong-code, internal-error and
RTL bugs the GocciaScript compiler bug hunt found, carry the wasm32 work, and (0079) give a library or package
the global-dynamic TLS model that a compiler with section threadvars otherwise used only with `-Cg`.
0080-0113 are the x86_64 code generation work of the November 2026 benchmark loop against gcc (register
variables with exception handling, loop and induction variable optimisations, inlining at -O3, the SLP
vectoriser at -O4 with its `SLP` optimizer switch, peephole rules), together with the wrong-code bugs it found
in the base (constant propagation inside an assignment, inline routines with try, procvars from inline
routines, record promotion with exceptions, x86 peephole aliasing, flags of float compares) and in its own work;
every patch that fixes wrong code carries a test under `tests/test`. `toolchain.conf` pins the
resulting tree (`FPC_EXPECT_TREE`), so the build fails if the base or the series drifts.

To take a new series from a branch built on the same base:

    scripts/update-series.sh 3.3.1 <git-url>#<branch>

It rewrites `patches/`, updates `FPC_EXPECT_TREE` and writes `SERIES_AUTHOR` into our own patches. Review the
diff, commit, and tag the next build (`3.3.1-b<N+1>`).
