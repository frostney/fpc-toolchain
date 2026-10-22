# Design

How these repositories build, package and install Free Pascal. The two repositories, `fpc-toolchain-3.2.4` and
`fpc-toolchain-3.3.1`, share every script and workflow. Only `toolchain.conf`, `patches/`,
`targets/targets.tsv`, `README.md` and `MATRIX.md` differ.

## Source

`scripts/fetch-source.sh` builds the exact source tree:

1. Shallow-fetch `FPC_SOURCE_COMMIT` from GitLab.
2. Apply `patches/` with `git am`, in name order.
3. Check the result against `FPC_EXPECT_TREE` (a git tree hash), if set.

| | 3.2.4 | 3.3.1 |
|---|---|---|
| base | `release_3_2_4-branch` at `82947b0d`: tag `release_3_2_4_rc2` plus 8 commits, the commit the final will be cut from | `main` at `fa51767875` |
| patches | 2 fcl-process fixes from `fixes_3_2` | the bug-hunt series and the wasm32 work |

`scripts/update-series.sh <url>#<ref>` replaces `patches/` with the commits of a branch on top of the base and
updates `FPC_EXPECT_TREE`. Patches by `SERIES_AUTHOR` (in `toolchain.conf`) get that author's address.

For 3.2.4 final: point `FPC_SOURCE_COMMIT` at the `release_3_2_4` tag, drop the patches the final contains, set
`FPC_UPSTREAM_MINORPATCH=` and tag `3.2.4-b1`.

## Builds and tags

The build writes `<upstream minorpatch>+<N>` into `version.pas`. `fpc -iW` then prints the build
(`3.2.4-rc2+1`, `3.3.1+1`). `fpc -iV`, the unit directory, `$fpcversion` and `FPC_FULLVERSION` stay upstream's.

The release tag is the build with `-b` instead of `+` (`3.2.4-rc2-b1`), so URLs need no escaping. `N` goes up
for any change that can change the output and restarts at 1 when the upstream version changes. The installers
and the action accept either form.

Each archive carries `share/fpc-toolchain/BUILDINFO` (build, source commit, patch series hash, tree, bootstrap
compiler, build run), `targets.tsv`, `cross-status.tsv` and the installer scripts.

## Release assets

| asset | contents |
|---|---|
| `fpc-<tag>-<host>.tar.xz` (`.zip` on Windows) | compiler, tools, every cross compiler that host ships, the host's own units |
| `fpc-<tag>-units-<target>.tar.xz` (and `.zip` when a Windows host ships it) | RTL and packages for one target, for every host |
| `fpc-<tag>-source.tar.xz`, `fpc-<tag>-source-patches.tar.xz` | the complete source as built, and the patches |
| `SHA256SUMS` | every file above |

Units don't depend on the host, so one units archive serves all hosts. A host archive with every target's units
would be 1-3 GB.

## Targets per host

`targets/targets.tsv` has one row per target the compiler knows: class, the hosts that ship it, the binutils
prefix, build options and notes. Classes:

- **internal**: FPC's own assembler and linker. Shipped on every host.
- **clang**: clang assembles (aarch64-win64, Darwin, iOS). Shipped on every host.
- **binutils**: needs GNU `as` and `ld`. Shipped on Linux; on macOS where Homebrew has the binutils
  (x86_64-linux, arm-linux, mips/mipsel-linux, arm-none-eabi).
- **sdk**: units build; linking needs a vendor SDK or sysroot we don't ship. Same hosts as binutils.
- **excluded**: not shipped. The notes say why.

Each build's `fpc.cfg` maps every cross target to its binutils prefix (`-XPaarch64-linux-gnu-`). FPC's default
(`aarch64-linux-`) matches no distribution.

Host limits:

- Windows has no packaged GNU cross binutils, so Windows hosts ship internal and clang targets only.
- Homebrew has no aarch64-linux binutils, so macOS doesn't ship aarch64-linux.
- Hosts without an 80-bit `Extended` (arm64, Windows) build x86 cross compilers only with
  `-dFPC_SOFT_FPUX80`. That doesn't compile in 3.2.4, so 3.2.4 ships no i386, i8086 or x86_64 targets there.
  3.3.1 builds them.

Build details in `targets.tsv`: one SUBARCH per embedded target; i8086 RTLs with `-CX -XXs` (the system unit
overflows a 64 KB code segment otherwise); mips64 needs `PPSUF=mips64`; Solaris uses GNU as (`-Aas`). If a
target's RTL builds but its packages don't, the build ships compiler and RTL (`rtl-only`). i8086-embedded units go
to `units/embedded`, where its compiler looks.

## Install layout

Linux and macOS, under `~/.local/share/fpc-toolchains`:

```
toolchains/3.2.4-rc2+1/      one build in FPC's Unix layout, etc/fpc.cfg written at install
toolchains/3.2.4 -> 3.2.4-rc2+1
bin/fpc-3.2.4                runs that build with -n @<its fpc.cfg>
bin/ppcx64-3.2.4, ...        for `fpc -V3.2.4`
etc/fpc.cfg                  includes each version's fpc.cfg under #IFDEF VER3_2_4
```

The compiler looks for `fpc.cfg` in `.`, `~/.fpc.cfg`, then `<exe dir>/../etc`, then `/etc`
(`options.pas`, `check_configfile`). Linux resolves the compiler's own path, so `lib/fpc/etc -> ../../etc`
points it at its build's config. `./fpc.cfg` and `~/.fpc.cfg` still win for plain `fpc`; the installer warns,
and `fpc-<version>` ignores them.

Windows, under `%LOCALAPPDATA%\fpc-toolchains`, uses FPC's Windows layout per build (`bin\<host>\`,
`units\`), a junction per version and `bin\fpc-<version>.cmd`. `fpc -V` isn't offered there: it needs symlinks.

## Pipeline

`.github/workflows/build.yml`, on a tag or by hand:

| job | runner | does |
|---|---|---|
| source | ubuntu-24.04 | fetch and check the source, source archives |
| linux-x86_64 | ubuntu-24.04 | native, every Linux cross target with its units archive, both Windows hosts |
| native | ubuntu-24.04-arm, macos-15, macos-15-intel | native toolchain and its cross compilers |
| verify-posix, verify-windows | all six | install the archives, hello world for every shipped target |
| release | ubuntu-24.04 | `check-release.sh`: every host archive, every units archive, source, sums; on a tag, a draft release |
| action-test | all six | the action from the checkout: install, run, cross-compile, cache hit |
| publish | ubuntu-24.04 | on a tag: publish the draft, fast-forward the `v<version>` branch |

Notes:

- Bootstrap: official FPC 3.2.2 binaries, sha256-pinned in `bootstrap.sh`.
- Windows hosts are built on Linux (`make all OS_TARGET=win64 BUILDFULLNATIVE=1`, `make install UNIXHier=`).
  It's the only way to get an aarch64-win64 compiler, and it needs no Windows bootstrap.
- Smoke gates (`check-smoke.sh`): no compile or run failure, internal and binutils targets must link, and
  `SMOKE_REQUIRE_RUN` targets must run (3.3.1: `wasm32-wasip1` under wasmtime).
- `smoke.yml` installs published releases from their public URLs, next to the sibling version, weekly and on
  demand.

## The GitHub Action

`action.yml` is a composite action around `scripts/action.sh`. The work is shell and the installers already
exist, so a JavaScript action would add a bundle and a Node runtime without removing any shell. Caching
uses `actions/cache` as a step.

1. **resolve**: map the runner to a host, check every requested target against `targets.tsv`, pick the release
   (input, else the tag the action is used at, else the newest), compute the cache key
   (repository, tag, host, sorted targets).
2. **cache**: `actions/cache` on the install directory, which sits in the runner tool cache
   (`$RUNNER_TOOL_CACHE/fpc-toolchain/<tag>/<host>-<targets hash>`). Self-hosted runners keep it across jobs.
3. **install**: unless the directory is complete, download the assets with `gh release download` and install
   them with `install.sh` or `install.ps1`, which check `SHA256SUMS`. Then check `fpc -iW` and set PATH.
4. **sysroots** (optional): `fpc-sysroot.sh`, cached the same way.

`@<tag>` pins a build. `@v<version>` is a branch that `publish` fast-forwards to each new build.

## Licences

The scripts and docs are Unlicense or MIT, the user's choice. FPC keeps its own licences: the compiler is GPL 2.0
or later, the RTL and packages are LGPL with the static-linking exception (`rtl/COPYING.FPC`). The patches keep
the licence of the files they change. Releases carry the complete corresponding source. No binutils, emulator,
SDK or sysroot is redistributed.
