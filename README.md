# fpc-toolchain-3.2.4

FPC 3.2.4 (release candidate 2, with two fcl-process fixes) for Linux, macOS and Windows, with every cross compiler each host can run. It installs next to any other FPC on the machine, and as a GitHub Action it caches itself between runs.

## GitHub Actions

```yaml
- uses: frostney/fpc-toolchain-3.2.4@v3.2.4
  with:
    targets: x86_64-win64,aarch64-linux   # optional, default: native only
- run: fpc hello.pas   # or fpc-3.2.4 hello.pas
```

`@v3.2.4` follows the newest build, `@3.2.4-rc2-b1` pins one. The toolchain is cached between runs. Inputs and outputs are under [Reference](#reference).

## Install locally

```sh
curl -fsSLO https://raw.githubusercontent.com/frostney/fpc-toolchain-3.2.4/main/scripts/install.sh
sh install.sh 3.2.4-rc2-b1 --targets x86_64-win64,aarch64-linux
export PATH="$HOME/.local/share/fpc-toolchains/bin:$PATH"
```

```powershell
iwr https://raw.githubusercontent.com/frostney/fpc-toolchain-3.2.4/main/scripts/install.ps1 -OutFile install.ps1
./install.ps1 -Identity '3.2.4-rc2-b1' -Targets x86_64-win64
```

## Pick a version

- `fpc-3.2.4 hello.pas` uses this build and only its own `fpc.cfg`.
- `fpc -V3.2.4 hello.pas` is FPC's own switch. It works with any `fpc` once the install `bin/` is on PATH (not on Windows).
- `eval "$(fpc-toolchain env 3.2.4)"` puts this build first on PATH, for build scripts and `instantfpc`.

## Targets

| host | cross targets |
|---|---|
| Linux x86_64 (`x86_64-linux`) | 50 |
| Linux arm64 (`aarch64-linux`) | 22 |
| macOS arm64 (`aarch64-darwin`) | 8 |
| macOS x86_64 (`x86_64-darwin`) | 23 |
| Windows x64 (`x86_64-win64`) | 3 |

[MATRIX.md](MATRIX.md) lists each target with its smoke result, and why the 33 others aren't shipped.

## Builds and tags

`fpc -iW` prints the build, for example `3.2.4-rc2+1`. Its release tag uses `-b` instead of `+`: `3.2.4-rc2-b1`. `fpc -iV` stays `3.2.4`, so unit paths and `$fpcversion` behave as usual. When 3.2.4 final ships, builds restart at `3.2.4-b1`.

## Licences

The scripts and docs here are yours under the Unlicense ([LICENSE](LICENSE)) or MIT ([LICENSE-MIT](LICENSE-MIT)), whichever you prefer. FPC keeps its own licences: the compiler is GPL 2.0 or later, the RTL and packages are LGPL with a static-linking exception (`rtl/COPYING.FPC`). Each release ships the complete source, and each patch in `patches/` keeps the licence of the file it changes.

## Reference

Action inputs:

| input | default | |
|---|---|---|
| `targets` | none | cross targets, comma separated |
| `release` | the tag you use, else the newest | a tag (`3.2.4-rc2-b1`) or build (`3.2.4-rc2+1`) |
| `fpc` | `true` | also put this build's plain `fpc`, `instantfpc`, `fpcres` first on PATH |
| `cache` | `true` | cache the toolchain and sysroots |
| `sysroots` | none | Linux targets that need a libc sysroot, for example `aarch64-linux` |
| `sysroot-packages` | none | extra Ubuntu packages for the sysroots, for example `libicu74` |

Outputs: `path` (the installed build), `version`, `identity`, `tag`, `cache-hit`, `sysroot-dir`, `sysroot-options`. Runners: `ubuntu-latest`, `ubuntu-24.04-arm`, `macos-latest`, `macos-15-intel`, `windows-latest`. Another host, or a target the host doesn't ship, stops the action with an error. The action checks the archives against `SHA256SUMS`, caches them with actions/cache in the runner tool cache, and uses a cached toolchain only if `fpc -iW` still matches.

Local installs: `--targets all` takes every target your host ships. Builds go to `~/.local/share/fpc-toolchains` (`%LOCALAPPDATA%\fpc-toolchains` on Windows); delete a build's directory to remove it. `toolchain.lock` ([example](toolchain.lock.example)) pins a build for a project: `sh install.sh --lock toolchain.lock` installs it, `fpc-toolchain check --lock toolchain.lock` fails on any other compiler.

Host limits:

- Windows hosts ship the targets that need only FPC's own assembler and linker, or clang. There are no packaged GNU cross binutils for Windows.
- macOS hosts ship those plus the Linux and embedded targets whose binutils Homebrew packages: x86_64-linux, arm-linux, mips/mipsel-linux and arm-none-eabi. Homebrew has no aarch64-linux binutils.
- FPC 3.2.4 can't build i386, i8086 or x86_64 cross compilers on hosts without an 80-bit `Extended` (arm64 and Windows). Its soft-float fallback doesn't compile. FPC 3.2 has no Windows arm64 at all.
- Targets that link against a vendor SDK (Apple, Android NDK, Solaris, Haiku, AROS, devkitARM, OpenBSD libc) ship compiler and units. You bring the SDK.

Linking libc (C libraries, `cthreads`) for another Linux needs that target's libc: `fpc-sysroot aarch64-linux <dir>` fetches it from Ubuntu packages and prints the FPC options.

How it is built and why: [DESIGN.md](DESIGN.md).
