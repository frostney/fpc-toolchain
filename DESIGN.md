# Design

How this repository builds, packages and installs Free Pascal. Each version has a directory,
`versions/<version>/`, with `toolchain.conf`, `patches/`, `targets.tsv` and `MATRIX.md`. Scripts, workflows and
the action are shared; every script takes the version (`fetch-source.sh 3.3.1 DIR`,
`build-toolchain.sh --version 3.3.1 ...`).

## Source

`scripts/fetch-source.sh` builds the exact source tree:

1. Shallow-fetch `FPC_SOURCE_COMMIT` from GitLab.
2. Apply `versions/<version>/patches/` with `git am`, in name order.
3. Check the result against `FPC_EXPECT_TREE` (a git tree hash), if set.

| | 3.2.4 | 3.3.1 |
|---|---|---|
| base | `release_3_2_4-branch` at `82947b0d`: tag `release_3_2_4_rc2` plus 8 commits, the commit the final will be cut from | `main` at `fa51767875` |
| patches | 2 fcl-process fixes from `fixes_3_2` | the bug-hunt series and the wasm32 work |

`scripts/update-series.sh <version> <url>#<ref>` replaces `patches/` with the commits of a branch on top of the base and
updates `FPC_EXPECT_TREE`. Patches by `SERIES_AUTHOR` (in `toolchain.conf`) get that author's address.

For 3.2.4 final: point `FPC_SOURCE_COMMIT` at the `release_3_2_4` tag, drop the patches the final contains, set
`FPC_UPSTREAM_MINORPATCH=` and tag `3.2.4-b1`.

## Builds and tags

The build writes `<upstream minorpatch>+<N>` into `version.pas`. `fpc -iW` then prints the build
(`3.2.4-rc2+1`, `3.3.1+1`). `fpc -iV`, the unit directory, `$fpcversion` and `FPC_FULLVERSION` stay upstream's.

The release tag is the build with `-b` instead of `+` (`3.2.4-rc2-b1`), so URLs need no escaping. `N` goes up
for any change that can change the output and restarts at 1 when the upstream version changes. The installers
and the action accept either form.

A tag builds only its version (`3.2.4-rc2-b1` builds 3.2.4), and each version has its own releases and
`SHA256SUMS`.

Each archive carries `share/fpc-toolchain/BUILDINFO` (build, source commit, patch series hash, tree, bootstrap
compiler, build run), `targets.tsv`, `cross-status.tsv` and the installer scripts.

## Release assets

| asset | contents |
|---|---|
| `fpc-<tag>-<host>.tar.xz` (`.zip` on Windows) | compiler, tools, every cross compiler that host ships, its GNU binutils (`cross/bin`), the host's own units |
| `fpc-<tag>-units-<target>.tar.xz` (and `.zip` when a Windows host ships it) | RTL and packages for one target, for every host |
| `fpc-<tag>-source.tar.xz`, `fpc-<tag>-source-patches.tar.xz` | the complete source as built, and the patches |
| `binutils-2.42.tar.xz` | the GNU binutils source the shipped `cross/bin` tools are built from |
| `SHA256SUMS` | every file above |

Units don't depend on the host, so one units archive serves all hosts. A host archive with every target's units
would be 1-3 GB.

## Targets per host

`versions/<version>/targets.tsv` has one row per target the compiler knows: class, the hosts that ship it, the
binutils prefix, build options and notes. Classes:

- **internal**: FPC's own assembler and linker.
- **clang**: clang assembles (aarch64-win64, Darwin, iOS).
- **binutils**: needs GNU `as` and `ld`.
- **sdk**: units build; linking needs a vendor SDK or sysroot we don't ship.
- **excluded**: not shipped. The notes say why: no free assembler or linker, a dead platform, or a compiler bug.

Every host ships every class but `excluded`. `scripts/build-binutils.sh` builds GNU binutils 2.42 (sha256-pinned)
for each prefix a host needs (`binutils-triples.sh`): natively on Linux and macOS, and for Windows on Linux with
llvm-mingw (`--host x86_64-w64-mingw32`, static). CI caches them per host and target list. They go into the
build's `cross/bin`, and its `fpc.cfg` finds them with `-FD` and maps each target to its prefix
(`-XPaarch64-linux-gnu-`; FPC's default `aarch64-linux-` matches no distribution).

Limits:

- Hosts without an 80-bit `Extended` build x86 cross compilers only with `-dFPC_SOFT_FPUX80`. That doesn't
  compile in 3.2.4 (`i386/cpuinfo.pas`), so 3.2.4 on Linux arm64 ships no i386, i8086 or x86_64 targets.
  3.3.1 builds them.
- 3.2.4 on Apple Silicon gets those targets from the x86_64 macOS build, under Rosetta 2: the installer and the
  action fetch it and add `ppcrossx64`, `ppcross386` and `ppcross8086` wrappers when an x86 target is asked for
  (`ROSETTA_X86=1` in `toolchain.conf`).
- 3.2.4 on Windows x64: Windows has no x87 `Extended` either, but FPC can turn it on there
  (`FPC_SUPPORT_X87_TYPES_ON_WIN64`). The build makes an x87 Linux-to-win64 compiler, a win64 RTL with it, and
  then the i386 and i8086 cross compilers for Windows.
- 3.3.1 builds the x86 cross compilers on arm64 hosts with soft x80. Patch 0078 gives `i8086/cpuinfo.pas` the
  branch for hosts without `Extended` that i386 and x86_64 already have.
- Units store real constants at the compiler's `Extended` size. Windows x64 has none, so its `ppcx64.exe` reads
  them as Double and fails on the 80-bit units of the other x86_64 targets (internal error 200208151). For
  3.3.1 (`SOFT_FPUX80=1`) the build replaces it with a soft-x80 `ppcx64.exe`; win64 output is byte-identical.
  3.2.4 can't build soft x80, so its Windows x64 host ships no x86_64 target but win64.
- Hosts without `Extended` round `Extended` constants for x86 targets to Double at compile time.
- FPC 3.2 has no Windows arm64 host.

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
| binutils | Linux and macOS runners | GNU binutils for each of the six hosts (Windows ones on Linux), cached |
| linux-x86_64 | ubuntu-24.04 | native, every cross target with its units archive, the Windows hosts |
| native | ubuntu-24.04-arm, macos-15, macos-15-intel | native toolchain and its cross compilers |
| verify-posix, verify-windows | all six | install the archives, hello world for every shipped target, with only the shipped binutils |
| release | ubuntu-24.04 | `check-release.sh`: every host archive, every units archive, sources, sums; on a tag, a draft release |
| action-test | all six | the action from the checkout: install, run, cross-compile, the other version next to it, cache hit |
| publish | ubuntu-24.04 | on a tag: publish the draft |

Artifacts are split by who needs them: `host-<host>`, `units-tar`, `units-zip` and `src-*`. A verify job downloads
its host archive and the units in its format, and a dry run's action test only `act-<host>` (host archive, one
units archive, `SHA256SUMS`). The release job takes all of them.

A run by hand is a dry run: build 0, nothing published. Its `other-run` input names a dry run of the other
version, so the action test installs both side by side before either is released. `ci.yml` lints and checks
both versions' source trees on every push.

Notes:

- Bootstrap: official FPC 3.2.2 binaries, sha256-pinned in `bootstrap.sh`.
- Windows hosts are built on Linux (`make all OS_TARGET=win64 BUILDFULLNATIVE=1`, `make install UNIXHier=`).
  It's the only way to get an aarch64-win64 compiler, and it needs no Windows bootstrap.
- Smoke gates (`check-smoke.sh`): no compile or run failure, internal and binutils targets must link, and
  `SMOKE_REQUIRE_RUN` targets must run (3.3.1: `wasm32-wasip1` under wasmtime).
- `smoke.yml` installs published releases from their public URLs, next to the other version's newest release,
  weekly and on demand.

## The GitHub Action

`action.yml` is a composite action around `scripts/action.sh`. The work is shell and the installers already
exist, so a JavaScript action would add a bundle and a Node runtime without removing any shell. Caching
uses `actions/cache` as a step.

1. **resolve**: take `version` (else `toolchain.lock`), map the runner to a host, check every requested target
   against that version's `targets.tsv`, pick the release (a pinned build, else the newest of that version),
   compute the cache key (repository, tag, host, sorted targets).
2. **cache**: `actions/cache` on the install directory, which sits in the runner tool cache
   (`$RUNNER_TOOL_CACHE/fpc-toolchain/<tag>/<host>-<targets hash>`). Self-hosted runners keep it across jobs.
3. **install**: unless the directory is complete, download the assets with `gh release download` and install
   them with `install.sh` or `install.ps1`, which check `SHA256SUMS`. Then check `fpc -iW` and set PATH.
4. **sysroots** (optional): `fpc-sysroot.sh`, cached the same way.

The action is versioned apart from the toolchains: `@v1` is a branch, fast-forwarded only to commits whose action
test passed on every runner. The toolchain build comes from `version`. Using the action twice installs two
versions side by side, each in its own directory with its own cache entry.

## Licences

The scripts and docs are Unlicense or MIT, the user's choice. FPC keeps its own licences: the compiler is GPL 2.0
or later, the RTL and packages are LGPL with the static-linking exception (`rtl/COPYING.FPC`). The patches keep
the licence of the files they change. GNU binutils is GPL 3.0 or later; releases carry its source next to FPC's
complete corresponding source. No emulator, SDK or sysroot is redistributed.
