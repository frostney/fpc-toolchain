# FPC 3.3.1 targets

Which host ships which target. `x` ships, `r` ships through the x86_64 macOS build under Rosetta 2, `-` doesn't. Every build compiles hello world for every target on every host; `compile`, `link` and `run` below are the Linux x86_64 results (`run` under qemu-user, wine or wasmtime). `sdk` targets compile; link them with your own SDK.

| host | targets (incl. native) |
|---|---|
| x86_64-linux | 68 |
| aarch64-linux | 65 |
| aarch64-darwin | 65 |
| x86_64-darwin | 68 |
| x86_64-win64 | 68 |
| aarch64-win64 | 65 |

| target | class | L64 | La64 | Ma64 | Mx64 | W64 | Wa64 | compile | link | run | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| x86_64-linux | binutils | x | x | x | x | x | x | ok | ok | ok | GNU ld (as is internal); static, no libc for plain programs; cthreads/C libs need a sysroot |
| aarch64-linux | binutils | x | x | x | x | x | x | ok | ok | ok | static, no libc for plain programs; cthreads/C libs need a sysroot |
| i386-linux | binutils | x | x | x | x | x | x | ok | ok | ok |  |
| arm-linux | binutils | x | x | x | x | x | x | ok | ok | ok | FPC default ARM ABI (EABI); armhf via -CaEABIHF -CfVFPV3 |
| powerpc-linux | binutils | x | x | x | x | x | x | ok | ok | ok |  |
| powerpc64-linux | binutils | x | x | x | x | x | x | ok | ok | ok | big-endian ELFv1 |
| mips-linux | binutils | x | x | x | x | x | x | ok | ok | ok |  |
| mipsel-linux | binutils | x | x | x | x | x | x | ok | ok | ok |  |
| sparc-linux | binutils | x | x | x | x | x | x | ok | ok | ok | sparc64 binutils in 32-bit mode |
| sparc64-linux | binutils | x | x | x | x | x | x | ok | ok | ok |  |
| m68k-linux | binutils | x | x | x | x | x | x | ok | ok | ok |  |
| riscv32-linux | binutils | x | x | x | x | x | x | ok | ok | ok |  |
| riscv64-linux | binutils | x | x | x | x | x | x | ok | ok | ok |  |
| loongarch64-linux | binutils | x | x | x | x | x | x | ok | ok | ok |  |
| x86_64-win64 | internal | x | x | x | x | x | x | ok | ok | ok | internal assembler + PE linker |
| i386-win32 | internal | x | x | x | x | x | x | ok | ok | ok | internal assembler + PE linker |
| aarch64-win64 | clang | x | x | x | x | x | x | ok | ok | no-emulator | clang assembles, internal PE linker; run on Windows ARM64 |
| wasm32-wasip1 | internal | x | x | x | x | x | x | ok | ok | ok | internal assembler + wasm linker |
| wasm32-wasip1threads | internal | x | x | x | x | x | x | ok | ok | no-emulator |  |
| wasm32-embedded | internal | x | x | x | x | x | x | ok | - | - | linking needs wasm-ld (lld) |
| i386-go32v2 | internal | x | x | x | x | x | x | ok | ok | no-emulator | DOS (DJGPP): internal COFF assembler + linker; building the RTL needs the djgpp as (binutils-djgpp) |
| i386-nativent | internal | x | x | x | x | x | x | ok | ok | no-emulator | Windows NT native API |
| i386-wince | internal | x | x | x | x | x | x | ok | ok | no-emulator | Windows CE x86 |
| arm-wince | internal | x | x | x | x | x | x | ok | ok | no-emulator | Windows CE ARM |
| i8086-msdos | internal | x | - | - | x | x | - | ok | ok | no-emulator | DOS 16-bit, internal OMF assembler + linker; RTL needs nasm; RTL built smartlinked (-CX -XXs): the system unit overflows one 64 KB code segment otherwise; not on arm64 hosts: trunk's i8086/cpuinfo.pas has no branch for hosts without 80-bit Extended (bestrealrec = TExtended80Rec; i386 and x86_64 have one), so ppcross8086 does not build there |
| i8086-embedded | internal | x | - | - | x | x | - | ok | - | - | RTL needs nasm; RTL built smartlinked (-CX -XXs): the system unit overflows one 64 KB code segment otherwise; not on arm64 hosts: trunk's i8086/cpuinfo.pas has no branch for hosts without 80-bit Extended (bestrealrec = TExtended80Rec; i386 and x86_64 have one), so ppcross8086 does not build there |
| i8086-win16 | sdk | x | - | - | x | x | - | ok | needs-sdk | - | linking needs OpenWatcom wlink; RTL built smartlinked (-CX -XXs): the system unit overflows one 64 KB code segment otherwise; not on arm64 hosts: trunk's i8086/cpuinfo.pas has no branch for hosts without 80-bit Extended (bestrealrec = TExtended80Rec; i386 and x86_64 have one), so ppcross8086 does not build there |
| z80-embedded | internal | x | x | x | x | x | x | ok | - | - | linking needs sdcc sdldz80 |
| x86_64-freebsd | binutils | x | x | x | x | x | x | ok | ok | no-emulator | ld with elf_x86_64_fbsd (binutils-x86-64-kfreebsd-gnu) |
| i386-freebsd | binutils | x | x | x | x | x | x | ok | ok | no-emulator |  |
| aarch64-freebsd | binutils | x | x | x | x | x | x | ok | ok | no-emulator |  |
| powerpc64-freebsd | binutils | x | x | x | x | x | x | ok | ok | no-emulator |  |
| x86_64-netbsd | binutils | x | x | x | x | x | x | ok | ok | no-emulator |  |
| i386-netbsd | binutils | x | x | x | x | x | x | ok | ok | no-emulator |  |
| m68k-netbsd | binutils | x | x | x | x | x | x | ok | ok | no-emulator |  |
| x86_64-openbsd | sdk | x | x | x | x | x | x | ok | needs-sdk | - | linking needs an OpenBSD libc sysroot (crt*.o, libc); x86_64 links with ld.lld |
| i386-openbsd | sdk | x | x | x | x | x | x | ok | needs-sdk | - | linking needs an OpenBSD libc sysroot (crt*.o, libc); x86_64 links with ld.lld |
| x86_64-dragonfly | binutils | x | x | x | x | x | x | ok | ok | no-emulator | links against libc: needs a DragonFly sysroot |
| x86_64-solaris | sdk | x | x | x | x | x | x | ok | needs-sdk | - | links against Solaris/illumos libc |
| i386-solaris | sdk | x | x | x | x | x | x | ok | needs-sdk | - | links against Solaris/illumos libc |
| sparc-solaris | sdk | x | x | x | x | x | x | ok | needs-sdk | - | links against Solaris/illumos libc; Solaris targets default to `gas`, built and used with GNU as (-Aas) |
| x86_64-haiku | sdk | x | x | x | x | x | x | ok | needs-sdk | - | needs Haiku cross binutils + sysroot |
| i386-haiku | sdk | x | x | x | x | x | x | ok | needs-sdk | - | needs Haiku cross binutils + sysroot |
| x86_64-aros | sdk | x | x | x | x | x | x | ok | needs-sdk | - | needs AROS SDK |
| i386-aros | sdk | x | x | x | x | x | x | ok | needs-sdk | - | needs AROS SDK |
| arm-aros | sdk | x | x | x | x | x | x | ok | needs-sdk | - | needs AROS SDK |
| aarch64-android | sdk | x | x | x | x | x | x | ok | needs-sdk | - | linking needs the Android NDK (not redistributable) |
| arm-android | sdk | x | x | x | x | x | x | ok | needs-sdk | - | linking needs the Android NDK |
| x86_64-android | sdk | x | x | x | x | x | x | ok | needs-sdk | - | linking needs the Android NDK |
| i386-android | sdk | x | x | x | x | x | x | ok | needs-sdk | - | linking needs the Android NDK |
| aarch64-darwin | clang | x | x | x | x | x | x | ok | needs-sdk | - | Linux hosts: units only (link needs Apple SDK + ld64, macOS only); macOS host: native |
| x86_64-darwin | clang | x | x | x | x | x | x | ok | needs-sdk | - | link needs Apple SDK + ld64 (macOS host); runs under Rosetta 2 |
| aarch64-ios | clang | x | x | x | x | x | x | ok | needs-sdk | - | link needs Xcode iOS SDK |
| aarch64-iphonesim | clang | x | x | x | x | x | x | ok | needs-sdk | - | link needs Xcode simulator SDK |
| x86_64-iphonesim | clang | x | x | x | x | x | x | ok | needs-sdk | - | link needs Xcode simulator SDK |
| arm-embedded | binutils | x | x | x | x | x | x | ok | - | - | units for one SUBARCH (armv7m, Cortex-M3); other SUBARCHes need their own build |
| avr-embedded | binutils | x | x | x | x | x | x | ok | - | - | units for SUBARCH avr5 (ATmega328P class) |
| riscv32-embedded | binutils | x | x | x | x | x | x | ok | - | - | SUBARCH rv32imac |
| aarch64-embedded | binutils | x | x | x | x | x | x | ok | - | - |  |
| x86_64-embedded | binutils | x | x | x | x | x | x | ok | - | - |  |
| i386-embedded | binutils | x | x | x | x | x | x | ok | - | - |  |
| m68k-embedded | binutils | x | x | x | x | x | x | ok | - | - |  |
| arm-freertos | sdk | x | x | x | x | x | x | ok | - | - | linking needs FreeRTOS |
| riscv32-freertos | sdk | x | x | x | x | x | x | ok | - | - | linking needs FreeRTOS and an ESP-IDF controller unit (none ships for riscv32); smoke compiles a unit |
| arm-gba | sdk | x | x | x | x | x | x | ok | needs-sdk | - | Game Boy Advance: linking needs devkitARM (libsysbase.a) |
| arm-nds | sdk | x | x | x | x | x | x | ok | needs-sdk | - | Nintendo DS: linking needs devkitARM libnds |
| mipsel-ps1 | binutils | x | x | x | x | x | x | ok | ok | no-emulator | PlayStation |
| powerpc-wii | sdk | x | x | x | x | x | x | ok | needs-sdk | - | needs devkitPPC/libogc |

Hosts: L64 x86_64-linux, La64 aarch64-linux, Ma64 aarch64-darwin, Mx64 x86_64-darwin, W64 x86_64-win64, Wa64 aarch64-win64.

## Not shipped (51)

| target | reason |
|---|---|
| armeb-linux | the big-endian ARM compiler is built under the little-endian name (ppcrossarm), so it cannot ship next to arm; only RTL built |
| mips64-linux | compiler internal error 2002122101 compiling rtl/inc/flt_core.inc (trunk mips64 backend) |
| mips64el-linux | compiler internal error 2002122101 compiling rtl/inc/flt_core.inc (trunk mips64 backend) |
| xtensa-linux | needs xtensa-linux-gnu binutils (not packaged; the lx106 ELF assembler rejects the Linux output) |
| wasm32-wasip2 | RTL skeleton (FPC marks wasip2 under development): WasmGrowMemoryCallback undefined |
| i386-netware | internal NetWare linker fails on hello world (undefined FPC_SYSTEMMAIN) |
| i386-netwlibc | RTL needs pre/libcpre.gcc.o from the Novell LibC SDK (not in the source tree) |
| i386-wdosx | no make target in trunk (removed from MAKEFILETARGETS) |
| z80-zxspectrum | the internal z80 linker does not link hello world yet (undefined PASCALMAIN; zxspectrum also needs ihxutil) |
| z80-msxdos | the internal z80 linker does not link hello world yet (undefined PASCALMAIN; zxspectrum also needs ihxutil) |
| z80-amstradcpc | the internal z80 linker does not link hello world yet (undefined PASCALMAIN; zxspectrum also needs ihxutil) |
| arm-netbsd | does not build from source: rtl/netbsd/arm has no syscallh.inc |
| powerpc-netbsd | not needed (owner) |
| mipsel-android | NDK dropped MIPS (r17, 2018) |
| arm-ios | 32-bit iOS: no current Xcode SDK can link it |
| i386-darwin | 32-bit macOS: no current SDK (removed in Xcode 10) |
| i386-iphonesim | 32-bit simulator: no current SDK |
| powerpc-darwin | PowerPC Mac OS X: needs Apple cctools as + 10.5 SDK |
| powerpc64-darwin | PowerPC Mac OS X: needs Apple cctools as + 10.5 SDK |
| riscv64-embedded | compiler internal error 200408222 compiling rtl/inc/genmath.inc |
| mipsel-embedded | does not build from source: rtl/embedded has no rule for mipsel/startup.s (SUBARCH pic32mx) |
| xtensa-embedded | Debian xtensa-lx106-elf as rejects the -EL option FPC passes for the embedded target (xtensa-freertos builds) |
| xtensa-freertos | pending: needs the core-specific (lx106) GNU binutils overlay, which plain binutils sources lack |
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
| m68k-sinclairql | needs vasm/vlink (non-commercial licence) |
| m68k-human68k | needs vasm/vlink (non-commercial licence) |
| m68k-palmos | needs PalmOS SDK + m68k a.out tools |
| jvm-java | needs a JDK + FPC's jasmin.jar (not in the source tree); RTL-only target |
| jvm-android | as jvm-java, plus Android SDK |
| armeb-embedded | does not build from source: rtl/embedded has no armeb/makefile.cpu |
| x86_6432-linux | x32 ABI: registered in the compiler but no RTL/make target |
| avr-freertosd | registered in the compiler but no RTL/make target |
| i386-freertos | registered in the compiler but no RTL/make target |
| i8086-freertos | registered in the compiler but no RTL/make target |
| m68k-freertos | registered in the compiler but no RTL/make target |
| mipsel-freertos | registered in the compiler but no RTL/make target |
| riscv64-freertos | registered in the compiler but no RTL/make target |
| x86_64-freertos | registered in the compiler but no RTL/make target |
