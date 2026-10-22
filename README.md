# fpc-toolchain

Free Pascal 3.2.4 and 3.3.1 for Linux, macOS and Windows, with every cross compiler each host can build from free tools. Both versions install side by side, next to any other FPC on the machine, and as a GitHub Action they cache themselves between runs.

- **3.2.4**: release candidate 2, with two fcl-process fixes.
- **3.3.1**: trunk, with our compiler and wasm32 fixes.

## GitHub Actions

```yaml
- uses: frostney/fpc-toolchain@v1
  with:
    version: 3.2.4
    targets: x86_64-win64,aarch64-linux   # optional, default: native only
- run: fpc hello.pas   # or fpc-3.2.4 hello.pas
```

Use it twice for both versions; `fpc-3.2.4` and `fpc-3.3.1` then both work, and plain `fpc` is the last one:

```yaml
- uses: frostney/fpc-toolchain@v1
  with: { version: 3.2.4 }
- uses: frostney/fpc-toolchain@v1
  with: { version: 3.3.1, targets: wasm32-wasip1 }
- run: fpc-3.2.4 hello.pas && fpc-3.3.1 -Pwasm32 -Twasip1 hello.pas
```

`version: 3.2.4` takes the newest 3.2.4 build, `version: 3.2.4-rc2-b1` pins one. Without `version`, the action reads `toolchain.lock`. Inputs and outputs are under [Reference](#reference).

## Install locally

```sh
curl -fsSLO https://raw.githubusercontent.com/frostney/fpc-toolchain/main/scripts/install.sh
sh install.sh 3.2.4-rc2-b1 --targets x86_64-win64,aarch64-linux
export PATH="$HOME/.local/share/fpc-toolchains/bin:$PATH"
```

```powershell
iwr https://raw.githubusercontent.com/frostney/fpc-toolchain/main/scripts/install.ps1 -OutFile install.ps1
./install.ps1 -Identity '3.2.4-rc2-b1' -Targets x86_64-win64
```

Run it again with another build to add it. Each build has its own directory.

## Pick a version

- `fpc-3.2.4 hello.pas` uses that build and only its own `fpc.cfg`.
- `fpc -V3.3.1 hello.pas` is FPC's own switch. It works with any `fpc` once the install `bin/` is on PATH (not on Windows).
- `eval "$(fpc-toolchain env 3.2.4)"` puts that build first on PATH, for build scripts and `instantfpc`.

## Targets

| host | 3.2.4 | 3.3.1 |
|---|---|---|
| Linux x86_64 (`x86_64-linux`) | 51 | 68 |
| Linux arm64 (`aarch64-linux`) | 23 | 65 |
| macOS arm64 (`aarch64-darwin`) | 51 | 65 |
| macOS x86_64 (`x86_64-darwin`) | 51 | 68 |
| Windows x64 (`x86_64-win64`) | 39 | 68 |
| Windows arm64 (`aarch64-win64`) | - | 65 |

Counts include the host itself. Every host ships the GNU binutils its targets need, built from source (binutils 2.42; the source is in each release). On Apple Silicon, 3.2.4's x86 targets run the x86_64 macOS compilers under Rosetta 2; the installer and the action set that up when you ask for one.

[versions/3.2.4/MATRIX.md](versions/3.2.4/MATRIX.md) and [versions/3.3.1/MATRIX.md](versions/3.3.1/MATRIX.md) list each target per host, and why the others aren't shipped.

## Builds and tags

`fpc -iW` prints the build, for example `3.2.4-rc2+1`. Its release tag uses `-b` instead of `+`: `3.2.4-rc2-b1`. `fpc -iV` stays `3.2.4`, so unit paths and `$fpcversion` behave as usual. A tag builds and releases only its own version. When 3.2.4 final ships, its builds restart at `3.2.4-b1`.

The action has its own version: `@v1` is a branch that moves forward only after the action test passed on every runner.

## Licences

The scripts and docs here are yours under the Unlicense ([LICENSE](LICENSE)) or MIT ([LICENSE-MIT](LICENSE-MIT)), whichever you prefer. FPC keeps its own licences: the compiler is GPL 2.0 or later, the RTL and packages are LGPL with a static-linking exception (`rtl/COPYING.FPC`). GNU binutils is GPL 3.0 or later. Each release ships the complete source, and each patch in `versions/*/patches/` keeps the licence of the file it changes.

## Reference

Action inputs:

| input | default | |
|---|---|---|
| `version` | the identity in `toolchain.lock` | `3.2.4` or `3.3.1` (newest build), a tag (`3.2.4-rc2-b1`) or a build (`3.2.4-rc2+1`) |
| `targets` | none | cross targets, comma separated |
| `fpc` | `true` | also put this build's plain `fpc`, `instantfpc`, `fpcres` first on PATH |
| `cache` | `true` | cache the toolchain and sysroots |
| `sysroots` | none | Linux targets that need a libc sysroot, for example `aarch64-linux` |
| `sysroot-packages` | none | extra Ubuntu packages for the sysroots, for example `libicu74` |
| `repository` | `frostney/fpc-toolchain` | where the releases come from |
| `archives` | none | a directory of already downloaded release assets |

Outputs: `path` (the installed build), `root`, `version`, `identity`, `tag`, `cache-hit`, `sysroot-dir`, `sysroot-options`. Runners: `ubuntu-24.04`, `ubuntu-24.04-arm`, `macos-15`, `macos-15-intel`, `windows-latest`, `windows-11-arm` (3.3.1 only). Another host, or a target the host doesn't ship, stops the action with an error. The action checks the archives against `SHA256SUMS`, caches them with actions/cache in the runner tool cache, and uses a cached toolchain only if `fpc -iW` still matches.

Local installs: `--targets all` takes every target your host ships. Builds go to `~/.local/share/fpc-toolchains` (`%LOCALAPPDATA%\fpc-toolchains` on Windows); delete a build's directory to remove it. `toolchain.lock` ([example](toolchain.lock.example)) pins a build for a project: `sh install.sh --lock toolchain.lock` installs it, `fpc-toolchain check --lock toolchain.lock` fails on any other compiler.

Limits:

- FPC 3.2.4 builds no i386, i8086 or x86_64 cross compilers on Linux arm64: that host has no 80-bit `Extended`, and 3.2.4's soft-float fallback doesn't compile. FPC 3.2 has no Windows arm64.
- FPC 3.3.1 builds no i8086 cross compiler on arm64 hosts: its `i8086/cpuinfo.pas` lacks the soft-float branch that i386 and x86_64 have.
- FPC 3.2.4 on Windows x64 has no x86_64 targets but Windows: its compiler has no 80-bit `Extended` and can't read their units. 3.3.1 reads them with soft x80.
- On hosts without 80-bit `Extended` (arm64, Windows), `Extended` constants for x86 targets are rounded to `Double` at compile time.
- Targets that link against a vendor SDK (Apple, Android NDK, Solaris, Haiku, AROS, devkitARM, OpenBSD libc) ship compiler and units. You bring the SDK.
- aarch64-win64 and the Darwin targets assemble with clang. GitHub's runners have it; elsewhere install LLVM.

Linking libc (C libraries, `cthreads`) for another Linux needs that target's libc: `fpc-sysroot aarch64-linux <dir>` fetches it from Ubuntu packages and prints the FPC options.

How it is built and why: [DESIGN.md](DESIGN.md).
