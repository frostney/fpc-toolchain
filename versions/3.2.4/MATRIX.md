# FPC 3.2.4 targets

Which host ships which target. `x` ships, `r` ships through the x86_64 macOS build under Rosetta 2, `-` doesn't. Every build compiles hello world for every target on every host; `compile`, `link` and `run` below are the Linux x86_64 results (`run` under qemu-user, wine or wasmtime). `sdk` targets compile; link them with your own SDK.

| host | targets (incl. native) |
|---|---|
| x86_64-linux | 51 |
| aarch64-linux | 23 |
| aarch64-darwin | 51 |
| x86_64-darwin | 51 |
| x86_64-win64 | 51 |

| target | class | L64 | La64 | Ma64 | Mx64 | W64 | compile | link | run | notes |
|---|---|---|---|---|---|---|---|---|---|---|
| x86_64-linux | binutils | x | - | r | x | x | ok | ok | ok | GNU ld (as is internal); static, no libc for plain programs; cthreads/C libs need a sysroot; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| aarch64-linux | binutils | x | x | x | x | x | ok | ok | ok | static, no libc for plain programs; cthreads/C libs need a sysroot |
| i386-linux | binutils | x | - | r | x | x | ok | ok | ok | 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| arm-linux | binutils | x | x | x | x | x | ok | ok | ok | FPC default ARM ABI (EABI); armhf via -CaEABIHF -CfVFPV3 |
| powerpc-linux | binutils | x | x | x | x | x | ok | ok | ok |  |
| powerpc64-linux | binutils | x | x | x | x | x | ok | ok | ok | big-endian ELFv1 |
| mips-linux | binutils | x | x | x | x | x | ok | ok | ok |  |
| mipsel-linux | binutils | x | x | x | x | x | ok | ok | ok |  |
| sparc-linux | binutils | x | x | x | x | x | ok | ok | ok | sparc64 binutils in 32-bit mode |
| sparc64-linux | binutils | x | x | x | x | x | ok | ok | ok |  |
| m68k-linux | binutils | x | x | x | x | x | ok | ok | ok |  |
| x86_64-win64 | internal | x | - | r | x | x | ok | ok | ok | internal assembler + PE linker; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-win32 | internal | x | - | r | x | x | ok | ok | ok | internal assembler + PE linker; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-go32v2 | internal | x | - | r | x | x | ok | ok | no-emulator | DOS (DJGPP): internal COFF assembler + linker; building the RTL needs the djgpp as (binutils-djgpp); 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-nativent | internal | x | - | r | x | x | ok | ok | no-emulator | Windows NT native API; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-wince | internal | x | - | r | x | x | ok | ok | no-emulator | Windows CE x86; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| arm-wince | internal | x | x | x | x | x | ok | ok | no-emulator | Windows CE ARM |
| i8086-msdos | internal | x | - | r | x | x | ok | ok | no-emulator | DOS 16-bit, internal OMF assembler + linker; RTL needs nasm; RTL built smartlinked (-CX -XXs): the system unit overflows one 64 KB code segment otherwise; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i8086-embedded | internal | x | - | r | x | x | ok | - | - | RTL needs nasm; RTL built smartlinked (-CX -XXs): the system unit overflows one 64 KB code segment otherwise; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| x86_64-freebsd | binutils | x | - | r | x | x | ok | ok | no-emulator | ld with elf_x86_64_fbsd (binutils-x86-64-kfreebsd-gnu); 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-freebsd | binutils | x | - | r | x | x | ok | ok | no-emulator | 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| x86_64-netbsd | binutils | x | - | r | x | x | ok | ok | no-emulator | 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-netbsd | binutils | x | - | r | x | x | ok | ok | no-emulator | 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| m68k-netbsd | binutils | x | x | x | x | x | ok | ok | no-emulator |  |
| x86_64-openbsd | sdk | x | - | r | x | x | ok | needs-sdk | - | linking needs an OpenBSD libc sysroot (crt*.o, libc); x86_64 links with ld.lld; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-openbsd | sdk | x | - | r | x | x | ok | needs-sdk | - | linking needs an OpenBSD libc sysroot (crt*.o, libc); x86_64 links with ld.lld; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| x86_64-dragonfly | binutils | x | - | r | x | x | ok | ok | no-emulator | links against libc: needs a DragonFly sysroot; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| x86_64-solaris | sdk | x | - | r | x | x | ok | needs-sdk | - | links against Solaris/illumos libc; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-solaris | sdk | x | - | r | x | x | ok | needs-sdk | - | links against Solaris/illumos libc; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| sparc-solaris | sdk | x | x | x | x | x | ok | needs-sdk | - | links against Solaris/illumos libc; Solaris targets default to `gas`, built and used with GNU as (-Aas) |
| x86_64-haiku | sdk | x | - | r | x | x | ok | needs-sdk | - | needs Haiku cross binutils + sysroot; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-haiku | sdk | x | - | r | x | x | ok | needs-sdk | - | needs Haiku cross binutils + sysroot; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| x86_64-aros | sdk | x | - | r | x | x | ok | needs-sdk | - | needs AROS SDK; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-aros | sdk | x | - | r | x | x | ok | needs-sdk | - | needs AROS SDK; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| arm-aros | sdk | x | x | x | x | x | ok | needs-sdk | - | needs AROS SDK |
| aarch64-android | sdk | x | x | x | x | x | ok | needs-sdk | - | linking needs the Android NDK (not redistributable) |
| arm-android | sdk | x | x | x | x | x | ok | needs-sdk | - | linking needs the Android NDK |
| x86_64-android | sdk | x | - | r | x | x | ok | needs-sdk | - | linking needs the Android NDK; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-android | sdk | x | - | r | x | x | ok | needs-sdk | - | linking needs the Android NDK; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| aarch64-darwin | clang | x | x | x | x | x | ok | needs-sdk | - | Linux hosts: units only (link needs Apple SDK + ld64, macOS only); macOS host: native |
| x86_64-darwin | clang | x | - | r | x | x | ok | needs-sdk | - | link needs Apple SDK + ld64 (macOS host); runs under Rosetta 2; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| aarch64-ios | clang | x | x | x | x | x | ok | needs-sdk | - | link needs Xcode iOS SDK |
| x86_64-iphonesim | clang | x | - | r | x | x | ok | needs-sdk | - | link needs Xcode simulator SDK; 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| arm-embedded | binutils | x | x | x | x | x | ok | - | - | units for one SUBARCH (armv7m, Cortex-M3); other SUBARCHes need their own build |
| avr-embedded | binutils | x | x | x | x | x | ok | - | - | units for SUBARCH avr5 (ATmega328P class) |
| x86_64-embedded | binutils | x | - | r | x | x | ok | - | - | 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| i386-embedded | binutils | x | - | r | x | x | ok | - | - | 3.2.x builds no x86 cross compilers on arm64 Linux (no 80-bit Extended; its soft-float fallback does not compile); on Apple Silicon via the x86_64-darwin build under Rosetta 2 |
| m68k-embedded | binutils | x | x | x | x | x | ok | - | - |  |
| arm-gba | sdk | x | x | x | x | x | ok | needs-sdk | - | Game Boy Advance: linking needs devkitARM (libsysbase.a) |
| arm-nds | sdk | x | x | x | x | x | ok | needs-sdk | - | Nintendo DS: linking needs devkitARM libnds |
| powerpc-wii | sdk | x | x | x | x | x | ok | needs-sdk | - | needs devkitPPC/libogc |

Hosts: L64 x86_64-linux, La64 aarch64-linux, Ma64 aarch64-darwin, Mx64 x86_64-darwin, W64 x86_64-win64.

## Not shipped (33)

| target | reason |
|---|---|
| armeb-linux | the big-endian ARM compiler is built under the little-endian name (ppcrossarm), so it cannot ship next to arm; only RTL built |
| i386-netware | internal NetWare linker fails on hello world (undefined FPC_SYSTEMMAIN) |
| i386-netwlibc | RTL needs pre/libcpre.gcc.o from the Novell LibC SDK (not in the source tree) |
| i386-wdosx | does not build from source: RTL fails to compile (syswin.inc: PascalMain, fpc_widestr_assign not found) |
| i8086-win16 | RTL needs the OpenWatcom librarian (wlib); 3.3.1 builds it without |
| arm-netbsd | does not build from source: rtl/netbsd/arm has no syscallh.inc |
| powerpc-netbsd | not needed (owner) |
| mipsel-android | NDK dropped MIPS (r17, 2018) |
| arm-ios | 32-bit iOS: no current Xcode SDK can link it |
| i386-darwin | 32-bit macOS: no current SDK (removed in Xcode 10) |
| i386-iphonesim | 32-bit simulator: no current SDK |
| powerpc-darwin | PowerPC Mac OS X: needs Apple cctools as + 10.5 SDK |
| powerpc64-darwin | PowerPC Mac OS X: needs Apple cctools as + 10.5 SDK |
| mipsel-embedded | does not build from source: rtl/embedded has no rule for mipsel/startup.s (SUBARCH pic32mx) |
| arm-palmos | needs PalmOS SDK (proprietary, not obtainable) |
| arm-symbian | Symbian SDK (discontinued) |
| i386-symbian | Symbian SDK (discontinued) |
| i386-beos | BeOS: needs BeOS binutils/sysroot; superseded by Haiku |
| i386-os2 | needs OS/2 EMX toolchain (emxbind, a.out as/ld) |
| i386-emx | needs EMX toolchain |
| i386-watcom | RTL startup needs the OpenWatcom assembler (wasm); OpenWatcom not packaged |
| powerpc-aix | needs AIX system as/ld (XCOFF) |
| powerpc64-aix | needs AIX system as/ld (XCOFF) |
| powerpc-amiga | needs AmigaOS 4 SDK |
| powerpc-macosclassic | needs Apple MPW |
| m68k-macosclassic | needs Apple MPW |
| m68k-amiga | needs m68k-amigaos a.out binutils or vasm/vlink (vasm/vlink: non-commercial licence) |
| m68k-atari | needs vasm/vlink (non-commercial licence) |
| m68k-palmos | needs PalmOS SDK + m68k a.out tools |
| jvm-java | needs a JDK + FPC's jasmin.jar (not in the source tree); RTL-only target |
| jvm-android | as jvm-java, plus Android SDK |
| armeb-embedded | does not build from source: rtl/embedded has no armeb/makefile.cpu |
| x86_6432-linux | x32 ABI: registered in the compiler but no RTL/make target |
