# Targets

Every target this FPC knows, built on Linux x86_64 and smoke-tested there with hello world. `build`: ok, `rtl-only` (packages don't build, compiler and RTL ship) or the failed attempt. `compile` assembles, `link` links, `run` runs natively, under qemu-user, wine or wasmtime. `-` means not applicable: embedded targets are compiled only, and `needs-sdk` targets link against an SDK we don't ship. `hosts` lists the hosts that ship the target.

| class | 3.2.4 |
|---|---|
| internal | 8 |
| binutils | 22 |
| clang | 4 |
| sdk | 17 |
| excluded | 33 |

## FPC 3.2.4

| target | class | build | compile | link | run | hosts | notes |
|---|---|---|---|---|---|---|---|
| x86_64-linux | binutils | native | ok | ok | ok | L64,Mx64 | GNU ld (as is internal); static, no libc for plain programs; cthreads/C libs need a sysroot; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| aarch64-linux | binutils | ok | ok | ok | ok | L64,La64 | static, no libc for plain programs; cthreads/C libs need a sysroot; not on macOS hosts: Homebrew has no aarch64-linux-gnu binutils |
| i386-linux | binutils | ok | ok | ok | ok | L64 | 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| arm-linux | binutils | ok | ok | ok | ok | L64,La64,Ma64,Mx64 | FPC default ARM ABI (EABI); armhf via -CaEABIHF -CfVFPV3 |
| armeb-linux | excluded | rtl-only | - | - | - |  | the big-endian ARM compiler is built under the little-endian name (ppcrossarm), so it cannot ship next to arm; only RTL built |
| powerpc-linux | binutils | ok | ok | ok | ok | L64,La64 |  |
| powerpc64-linux | binutils | ok | ok | ok | ok | L64,La64 | big-endian ELFv1 |
| mips-linux | binutils | ok | ok | ok | ok | L64,La64,Ma64,Mx64 |  |
| mipsel-linux | binutils | ok | ok | ok | ok | L64,La64,Ma64,Mx64 |  |
| sparc-linux | binutils | ok | ok | ok | ok | L64,La64 | sparc64 binutils in 32-bit mode |
| sparc64-linux | binutils | ok | ok | ok | ok | L64,La64 |  |
| m68k-linux | binutils | ok | ok | ok | ok | L64,La64 |  |
| x86_64-win64 | internal | ok | ok | ok | ok | L64,Mx64,W64 | internal assembler + PE linker; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| i386-win32 | internal | ok | ok | ok | ok | L64,Mx64 | internal assembler + PE linker; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| i386-go32v2 | internal | ok | ok | ok | no-emulator | L64,Mx64 | DOS (DJGPP): internal COFF assembler + linker; building the RTL needs the djgpp as (binutils-djgpp); 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, Windows: soft x80 fails in i386/cpuinfo.pas) |
| i386-nativent | internal | ok | ok | ok | no-emulator | L64,Mx64 | Windows NT native API; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| i386-wince | internal | ok | ok | ok | no-emulator | L64,Mx64 | Windows CE x86; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| arm-wince | internal | ok | ok | ok | no-emulator | L64,La64,Ma64,Mx64,W64 | Windows CE ARM |
| i386-netware | excluded | ok | - | - | - |  | internal NetWare linker fails on hello world (undefined FPC_SYSTEMMAIN) |
| i386-netwlibc | excluded | FAIL | - | - | - |  | RTL needs pre/libcpre.gcc.o from the Novell LibC SDK (not in the source tree) |
| i386-wdosx | excluded | FAIL | - | - | - |  | does not build from source: RTL fails to compile (syswin.inc: PascalMain, fpc_widestr_assign not found) |
| i8086-msdos | internal | ok | ok | ok | no-emulator | L64,Mx64 | DOS 16-bit, internal OMF assembler + linker; RTL needs nasm; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas); RTL built smartlinked (-CX -XXs): the system unit overflows one 64 KB code segment otherwise |
| i8086-embedded | internal | ok | ok | - | - | L64,Mx64 | RTL needs nasm; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas); RTL built smartlinked (-CX -XXs): the system unit overflows one 64 KB code segment otherwise |
| i8086-win16 | excluded | FAIL | - | - | - |  | RTL needs the OpenWatcom librarian (wlib); 3.3.1 builds it without |
| x86_64-freebsd | binutils | ok | ok | ok | no-emulator | L64 | ld with elf_x86_64_fbsd (binutils-x86-64-kfreebsd-gnu); 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| i386-freebsd | binutils | ok | ok | ok | no-emulator | L64 | 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| x86_64-netbsd | binutils | ok | ok | ok | no-emulator | L64 | 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| i386-netbsd | binutils | ok | ok | ok | no-emulator | L64 | 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| arm-netbsd | excluded | FAIL | - | - | - |  | does not build from source: rtl/netbsd/arm has no syscallh.inc |
| m68k-netbsd | binutils | ok | ok | ok | no-emulator | L64,La64 |  |
| powerpc-netbsd | excluded | - | - | - | - |  | not needed (owner) |
| x86_64-openbsd | sdk | ok | ok | needs-sdk | - | L64 | linking needs an OpenBSD libc sysroot (crt*.o, libc); x86_64 links with ld.lld; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, Windows: soft x80 fails in i386/cpuinfo.pas) |
| i386-openbsd | sdk | ok | ok | needs-sdk | - | L64 | linking needs an OpenBSD libc sysroot (crt*.o, libc); x86_64 links with ld.lld; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, Windows: soft x80 fails in i386/cpuinfo.pas) |
| x86_64-dragonfly | binutils | ok | ok | ok | no-emulator | L64 | links against libc: needs a DragonFly sysroot; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| x86_64-solaris | sdk | ok | ok | needs-sdk | - | L64,Mx64 | links against Solaris/illumos libc; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| i386-solaris | sdk | ok | ok | needs-sdk | - | L64 | links against Solaris/illumos libc; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| sparc-solaris | sdk | rtl-only | ok | needs-sdk | - | L64,La64 | links against Solaris/illumos libc; Solaris targets default to `gas`, built and used with GNU as (-Aas) |
| x86_64-haiku | sdk | ok | ok | needs-sdk | - | L64,Mx64 | needs Haiku cross binutils + sysroot; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| i386-haiku | sdk | ok | ok | needs-sdk | - | L64 | needs Haiku cross binutils + sysroot; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| x86_64-aros | sdk | ok | ok | needs-sdk | - | L64,Mx64 | needs AROS SDK; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| i386-aros | sdk | ok | ok | needs-sdk | - | L64 | needs AROS SDK; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| arm-aros | sdk | ok | ok | needs-sdk | - | L64,La64 | needs AROS SDK |
| aarch64-android | sdk | ok | ok | needs-sdk | - | L64,La64 | linking needs the Android NDK (not redistributable) |
| arm-android | sdk | ok | ok | needs-sdk | - | L64,La64 | linking needs the Android NDK |
| x86_64-android | sdk | ok | ok | needs-sdk | - | L64,Mx64 | linking needs the Android NDK; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| i386-android | sdk | ok | ok | needs-sdk | - | L64 | linking needs the Android NDK; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| mipsel-android | excluded | - | - | - | - |  | NDK dropped MIPS (r17, 2018) |
| aarch64-darwin | clang | ok | ok | needs-sdk | - | L64,La64,Ma64,Mx64,W64 | Linux hosts: units only (link needs Apple SDK + ld64, macOS only); macOS host: native |
| x86_64-darwin | clang | ok | ok | needs-sdk | - | L64,Mx64 | link needs Apple SDK + ld64 (macOS host); runs under Rosetta 2; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| aarch64-ios | clang | ok | ok | needs-sdk | - | L64,La64,Ma64,Mx64,W64 | link needs Xcode iOS SDK |
| x86_64-iphonesim | clang | ok | ok | needs-sdk | - | L64,Mx64 | link needs Xcode simulator SDK; 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| arm-ios | excluded | - | - | - | - |  | 32-bit iOS: no current Xcode SDK can link it |
| i386-darwin | excluded | - | - | - | - |  | 32-bit macOS: no current SDK (removed in Xcode 10) |
| i386-iphonesim | excluded | - | - | - | - |  | 32-bit simulator: no current SDK |
| powerpc-darwin | excluded | - | - | - | - |  | PowerPC Mac OS X: needs Apple cctools as + 10.5 SDK |
| powerpc64-darwin | excluded | - | - | - | - |  | PowerPC Mac OS X: needs Apple cctools as + 10.5 SDK |
| arm-embedded | binutils | ok | ok | - | - | L64,La64,Ma64,Mx64 | units for one SUBARCH (armv7m, Cortex-M3); other SUBARCHes need their own build |
| avr-embedded | binutils | ok | ok | - | - | L64,La64 | units for SUBARCH avr5 (ATmega328P class) |
| mipsel-embedded | excluded | FAIL | - | - | - |  | does not build from source: rtl/embedded has no rule for mipsel/startup.s (SUBARCH pic32mx) |
| x86_64-embedded | binutils | ok | ok | - | - | L64,Mx64 | 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| i386-embedded | binutils | ok | ok | - | - | L64 | 3.2.x cannot build x86 cross compilers on hosts without 80-bit Extended (aarch64, win64: soft x80 fails in i386/cpuinfo.pas) |
| m68k-embedded | binutils | ok | ok | - | - | L64,La64 |  |
| arm-gba | sdk | ok | ok | needs-sdk | - | L64,La64,Ma64,Mx64 | Game Boy Advance: linking needs devkitARM (libsysbase.a) |
| arm-nds | sdk | ok | ok | needs-sdk | - | L64,La64,Ma64,Mx64 | Nintendo DS: linking needs devkitARM libnds |
| powerpc-wii | sdk | ok | ok | needs-sdk | - | L64,La64 | needs devkitPPC/libogc |
| arm-palmos | excluded | - | - | - | - |  | needs PalmOS SDK (proprietary, not obtainable) |
| arm-symbian | excluded | - | - | - | - |  | Symbian SDK (discontinued) |
| i386-symbian | excluded | - | - | - | - |  | Symbian SDK (discontinued) |
| i386-beos | excluded | - | - | - | - |  | BeOS: needs BeOS binutils/sysroot; superseded by Haiku |
| i386-os2 | excluded | - | - | - | - |  | needs OS/2 EMX toolchain (emxbind, a.out as/ld) |
| i386-emx | excluded | - | - | - | - |  | needs EMX toolchain |
| i386-watcom | excluded | FAIL | - | - | - |  | RTL startup needs the OpenWatcom assembler (wasm); OpenWatcom not packaged |
| powerpc-aix | excluded | - | - | - | - |  | needs AIX system as/ld (XCOFF) |
| powerpc64-aix | excluded | - | - | - | - |  | needs AIX system as/ld (XCOFF) |
| powerpc-amiga | excluded | - | - | - | - |  | needs AmigaOS 4 SDK |
| powerpc-macosclassic | excluded | - | - | - | - |  | needs Apple MPW |
| m68k-macosclassic | excluded | - | - | - | - |  | needs Apple MPW |
| m68k-amiga | excluded | - | - | - | - |  | needs m68k-amigaos a.out binutils or vasm/vlink (vasm/vlink: non-commercial licence) |
| m68k-atari | excluded | - | - | - | - |  | needs vasm/vlink (non-commercial licence) |
| m68k-palmos | excluded | - | - | - | - |  | needs PalmOS SDK + m68k a.out tools |
| jvm-java | excluded | - | - | - | - |  | needs a JDK + FPC's jasmin.jar (not in the source tree); RTL-only target |
| jvm-android | excluded | - | - | - | - |  | as jvm-java, plus Android SDK |
| armeb-embedded | excluded | FAIL | - | - | - |  | does not build from source: rtl/embedded has no armeb/makefile.cpu |
| x86_6432-linux | excluded | - | - | - | - |  | x32 ABI: registered in the compiler but no RTL/make target |

Hosts: L64 x86_64-linux, La64 aarch64-linux, Ma64 aarch64-darwin, Mx64 x86_64-darwin, W64 x86_64-win64, Wa64 aarch64-win64.
