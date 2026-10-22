# Patches

Applied in name order on FPC `main` at `fa51767875` (2026-10-14). They fix the wrong-code, internal-error and
RTL bugs the GocciaScript compiler bug hunt found, and carry the wasm32 work. `toolchain.conf` pins the
resulting tree (`FPC_EXPECT_TREE`), so the build fails if the base or the series drifts.

To take a new series from a branch built on the same base:

    scripts/update-series.sh 3.3.1 <git-url>#<branch>

It rewrites `patches/`, updates `FPC_EXPECT_TREE` and writes `SERIES_AUTHOR` into our own patches. Review the
diff, commit, and tag the next build (`3.3.1-b<N+1>`).
