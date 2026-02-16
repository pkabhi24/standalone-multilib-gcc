# Standalone Multilib GCC Build

## Overview
This project demonstrates building a standalone Linux native GCC toolchain with multilib support for both 32-bit and 64-bit targets. 
The build is independent of system glibc libraries, ensuring portability across different Linux distributions and versions.

## Features
- Multilib support (32-bit and 64-bit)
- Standalone build (not dependent on host glibc)
- Portable across Linux systems
- Zero System dependency - Include its own glibc, headers and libraries.

## Sources Used
- Gcc 15.2.0
- glibc 2.39
- Binutils 2.45
- m4 1.4.20
- gmp 6.3.0
- mpfr 4.2.2
- mpc 1.3.1
- bison 3.8
- texinfo 7.2
- linux 6.16.5

## Build 
chmod +x build_gcc_multilib.sh
./build_gcc_multilib.sh

## Architecture
The toolchain uses a custom sysroot structure:
- `sysroot/lib64/` - 64-bit runtime libraries
- `sysroot/lib32/` - 32-bit runtime libraries
- `sysroot/usr/include/` - Headers (shared)

## Wrapper Scripts
`gcc` and `g++` are wrapper scripts that automatically:
- Set the correct sysroot path
- Configure dynamic linker paths
- Handle `-m32` vs `-m64` flags
- Set library search paths

## Portability
Works on any x86_64 Linux distribution:
- Ubuntu, Debian, Mint
- RHEL, CentOS, Fedora, Rocky
- Arch, Manjaro
- OpenSUSE, SLES

## License
This build script is released under the MIT License.
The compiled toolchain contains software under various licenses:
- GCC: GPL-3.0
- glibc: LGPL-2.1
- Binutils: GPL-3.0
- GMP, MPFR, MPC: LGPL-3.0

## Contributing
Contributions welcome! Please:
- Test changes on multiple Linux distributions
- Update documentation for any build process changes
- Report issues with detailed build logs

## Credits
Built with components from:
- GNU Project (GCC, glibc, Binutils)
- Linux Kernel Archives
- GNU MP, MPFR, MPC Projects

## Note
This is an independently built toolchain not affiliated with or endorsed by the GCC project or GNU.
