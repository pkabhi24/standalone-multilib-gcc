#!/bin/bash

# Complete Self-Contained GCC Multilib Toolchain Build Script
# Goal: Build a fully independent GCC with 32-bit AND 64-bit support
# Zero system dependencies - completely portable

set -e  # Exit on error
set -u  # Exit on undefined variable

#==============================================================================
# CONFIGURATION
#==============================================================================

# Versions
export M4_VERSION="m4-1.4.20"
export GMP_VERSION="gmp-6.3.0"
export MPFR_VERSION="mpfr-4.2.2"
export MPC_VERSION="mpc-1.3.1"
export GCC_VERSION="gcc-15.2.0"
export GLIBC_VERSION="glibc-2.39"  # CRITICAL: Use 2.39, NOT 2.42!
export BINUTILS_VERSION="binutils-2.45"
export BISON_VERSION="bison-3.8"
export TEXINFO_VERSION="texinfo-7.2"
export KERNEL_VERSION="linux-6.16.5"

# Directories
export WORKING_DIR="$(pwd)/gcc_15.2.0_lin"
export SOURCES_DIR="$WORKING_DIR/sources"
export BUILD_DIR="$WORKING_DIR/builds"
export GC_INSTALL_DIR="$WORKING_DIR/gcc-install"
export SYSROOT="$GC_INSTALL_DIR/sysroot"

# Targets
export TARGET_32_BIT="i686-pc-linux-gnu"
export TARGET_64_BIT="x86_64-pc-linux-gnu"

# Build settings
export MAKEFLAGS="-j$(nproc)"

#==============================================================================
# SETUP
#==============================================================================

echo "=========================================="
echo "MULTILIB GCC BUILD - 32-bit + 64-bit"
echo "=========================================="
echo "Working directory: $WORKING_DIR"
echo "Install directory: $GC_INSTALL_DIR"
echo "Sysroot: $SYSROOT"
echo ""

mkdir -p $SOURCES_DIR
mkdir -p $BUILD_DIR
mkdir -p $GC_INSTALL_DIR
mkdir -p $SYSROOT/{lib,lib32,lib64,include}
mkdir -p $SOURCES_DIR/{m4,gmp,mpfr,mpc,gcc,glibc,binutils,bison,texinfo,kernel}

# Update PATH
export PATH="$GC_INSTALL_DIR/bin:$PATH"

#==============================================================================
# DOWNLOAD AND EXTRACT
#==============================================================================

echo "=========================================="
echo "Downloading sources..."
echo "=========================================="

cd $SOURCES_DIR

[ -f ${M4_VERSION}.tar.gz ] || curl -LO https://mirror.dogado.de/gnu/m4/${M4_VERSION}.tar.gz
[ -f ${GMP_VERSION}.tar.xz ] || curl -LO https://ftp.gnu.org/gnu/gmp/${GMP_VERSION}.tar.xz
[ -f ${MPFR_VERSION}.tar.gz ] || curl -LO https://www.mpfr.org/mpfr-current/${MPFR_VERSION}.tar.gz
[ -f ${MPC_VERSION}.tar.gz ] || curl -LO https://www.multiprecision.org/downloads/${MPC_VERSION}.tar.gz
[ -f ${GCC_VERSION}.tar.gz ] || curl -LO https://ftp.fu-berlin.de/unix/languages/gcc/releases/${GCC_VERSION}/${GCC_VERSION}.tar.gz
[ -f ${GLIBC_VERSION}.tar.gz ] || curl -LO https://mirror.dogado.de/gnu/libc/${GLIBC_VERSION}.tar.gz
[ -f ${BINUTILS_VERSION}.tar.gz ] || curl -LO https://mirror.dogado.de/gnu/binutils/${BINUTILS_VERSION}.tar.gz
[ -f ${BISON_VERSION}.tar.gz ] || curl -LO https://mirror.dogado.de/gnu/bison/${BISON_VERSION}.tar.gz
[ -f ${TEXINFO_VERSION}.tar.gz ] || curl -LO https://mirror.dogado.de/gnu/texinfo/${TEXINFO_VERSION}.tar.gz
[ -f ${KERNEL_VERSION}.tar.xz ] || curl -LO https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_VERSION}.tar.xz

echo "=========================================="
echo "Extracting tarballs..."
echo "=========================================="

[ -d m4/${M4_VERSION} ] || tar -xf ${M4_VERSION}.tar.gz -C m4/
[ -d gmp/${GMP_VERSION} ] || tar -xf ${GMP_VERSION}.tar.xz -C gmp/
[ -d mpfr/${MPFR_VERSION} ] || tar -xf ${MPFR_VERSION}.tar.gz -C mpfr/
[ -d mpc/${MPC_VERSION} ] || tar -xf ${MPC_VERSION}.tar.gz -C mpc/
[ -d gcc/${GCC_VERSION} ] || tar -xf ${GCC_VERSION}.tar.gz -C gcc/
[ -d glibc/${GLIBC_VERSION} ] || tar -xf ${GLIBC_VERSION}.tar.gz -C glibc/
[ -d binutils/${BINUTILS_VERSION} ] || tar -xf ${BINUTILS_VERSION}.tar.gz -C binutils/
[ -d bison/${BISON_VERSION} ] || tar -xf ${BISON_VERSION}.tar.gz -C bison/
[ -d texinfo/${TEXINFO_VERSION} ] || tar -xf ${TEXINFO_VERSION}.tar.gz -C texinfo/
[ -d kernel/${KERNEL_VERSION} ] || tar -xf ${KERNEL_VERSION}.tar.xz -C kernel/

#==============================================================================
# BUILD PREREQUISITES
#==============================================================================

echo "=========================================="
echo "Building M4..."
echo "=========================================="
cd $BUILD_DIR
rm -rf m4-build && mkdir m4-build && cd m4-build
$SOURCES_DIR/m4/${M4_VERSION}/configure --prefix=$GC_INSTALL_DIR
make && make install

echo "=========================================="
echo "Building Bison..."
echo "=========================================="
cd $BUILD_DIR
rm -rf bison-build && mkdir bison-build && cd bison-build
$SOURCES_DIR/bison/${BISON_VERSION}/configure --prefix=$GC_INSTALL_DIR
make && make install

echo "=========================================="
echo "Building Texinfo..."
echo "=========================================="
cd $BUILD_DIR
rm -rf texinfo-build && mkdir texinfo-build && cd texinfo-build
$SOURCES_DIR/texinfo/${TEXINFO_VERSION}/configure --prefix=$GC_INSTALL_DIR
make && make install

#==============================================================================
# INSTALL LINUX KERNEL HEADERS
#==============================================================================

echo "=========================================="
echo "Installing Linux Kernel Headers..."
echo "=========================================="
cd $SOURCES_DIR/kernel/${KERNEL_VERSION}
make mrproper
make headers
make INSTALL_HDR_PATH=$SYSROOT/usr headers_install

ln -sf usr/include $SYSROOT/include 2>/dev/null || true

echo "✓ Kernel headers installed"

#==============================================================================
# BUILD BINUTILS (with multilib support)
#==============================================================================

echo "=========================================="
echo "Building Binutils (multilib)..."
echo "=========================================="
cd $BUILD_DIR
rm -rf binutils-build && mkdir binutils-build && cd binutils-build

$SOURCES_DIR/binutils/${BINUTILS_VERSION}/configure \
    --prefix=$GC_INSTALL_DIR \
    --with-sysroot=$SYSROOT \
    --enable-multilib \
    --enable-targets=i686-pc-linux-gnu,x86_64-pc-linux-gnu \
    --disable-nls \
	--disable-gprofng \
    --disable-werror \
    --enable-deterministic-archives

make
make install

echo "✓ Binutils installed (multilib enabled)"

#==============================================================================
# BOOTSTRAP GCC - STAGE 1 (with multilib)
#==============================================================================

echo "=========================================="
echo "Building Bootstrap GCC Stage 1 (multilib)..."
echo "=========================================="

cd $SOURCES_DIR/gcc/${GCC_VERSION}
ln -sf ../../gmp/${GMP_VERSION} gmp 2>/dev/null || true
ln -sf ../../mpfr/${MPFR_VERSION} mpfr 2>/dev/null || true
ln -sf ../../mpc/${MPC_VERSION} mpc 2>/dev/null || true

cd $BUILD_DIR
rm -rf gcc-stage1-build && mkdir gcc-stage1-build && cd gcc-stage1-build

$SOURCES_DIR/gcc/${GCC_VERSION}/configure \
    --prefix=$GC_INSTALL_DIR/bootstrap-gcc \
    --target=$TARGET_64_BIT \
    --build=$TARGET_64_BIT \
    --host=$TARGET_64_BIT \
    --with-sysroot=$SYSROOT \
    --with-newlib \
    --without-headers \
    --enable-languages=c,c++ \
    --enable-multilib \
    --with-multilib-list=m64,m32 \
    --disable-shared \
    --disable-threads \
    --disable-libssp \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libatomic \
    --with-as=$GC_INSTALL_DIR/bin/as \
    --with-ld=$GC_INSTALL_DIR/bin/ld

make all-gcc
make install-gcc
make all-target-libgcc
make install-target-libgcc

echo "✓ Bootstrap GCC Stage 1 installed (multilib)"

export PATH="$GC_INSTALL_DIR/bootstrap-gcc/bin:$GC_INSTALL_DIR/bin:$PATH"

#==============================================================================
# BUILD GLIBC HEADERS
#==============================================================================

echo "=========================================="
echo "Installing glibc headers..."
echo "=========================================="

cd $BUILD_DIR
rm -rf glibc-headers-build && mkdir glibc-headers-build && cd glibc-headers-build

$SOURCES_DIR/glibc/${GLIBC_VERSION}/configure \
    --prefix=/usr \
    --host=$TARGET_64_BIT \
    --build=$TARGET_64_BIT \
    --with-headers=$SYSROOT/usr/include \
    --enable-kernel=3.2 \
    --disable-werror \
    libc_cv_slibdir=/lib64

make install-headers install_root=$SYSROOT
touch $SYSROOT/usr/include/gnu/stubs.h

echo "✓ Glibc headers installed"

#==============================================================================
# BUILD GLIBC 64-BIT
#==============================================================================

echo "=========================================="
echo "Building glibc 64-bit..."
echo "=========================================="

cd $BUILD_DIR
rm -rf glibc-64-build && mkdir glibc-64-build && cd glibc-64-build

CC="$GC_INSTALL_DIR/bootstrap-gcc/bin/gcc -m64" \
CXX="$GC_INSTALL_DIR/bootstrap-gcc/bin/g++ -m64" \
$SOURCES_DIR/glibc/${GLIBC_VERSION}/configure \
    --prefix=/usr \
    --libdir=/lib64 \
    --host=$TARGET_64_BIT \
    --build=$TARGET_64_BIT \
    --with-headers=$SYSROOT/usr/include \
    --enable-kernel=3.2 \
    --enable-stack-protector=strong \
    --disable-werror \
    libc_cv_slibdir=/lib64

make
make install_root=$SYSROOT install

echo "✓ Glibc 64-bit installed"

#==============================================================================
# BUILD GLIBC 32-BIT
#==============================================================================

echo "=========================================="
echo "Building glibc 32-bit..."
echo "=========================================="

cd $BUILD_DIR
rm -rf glibc-32-build && mkdir glibc-32-build && cd glibc-32-build

CC="$GC_INSTALL_DIR/bootstrap-gcc/bin/gcc -m32" \
CXX="$GC_INSTALL_DIR/bootstrap-gcc/bin/g++ -m32" \
$SOURCES_DIR/glibc/${GLIBC_VERSION}/configure \
    --prefix=/usr \
    --libdir=/lib32 \
    --host=$TARGET_32_BIT \
    --build=$TARGET_64_BIT \
    --with-headers=$SYSROOT/usr/include \
    --enable-kernel=3.2 \
    --enable-stack-protector=strong \
    --disable-werror \
    libc_cv_slibdir=/lib32

make
make install_root=$SYSROOT install

echo "✓ Glibc 32-bit installed"

# Create symlinks for 32-bit startup files and dynamic linker in lib/
# GCC multilib expects alternate arch (32-bit) files in the base lib/ directory
echo "Creating symlinks for 32-bit startup files and dynamic linker..."
mkdir -p $SYSROOT/lib
ln -sf ../lib32/crt1.o $SYSROOT/lib/crt1.o 2>/dev/null || true
ln -sf ../lib32/crti.o $SYSROOT/lib/crti.o 2>/dev/null || true
ln -sf ../lib32/crtn.o $SYSROOT/lib/crtn.o 2>/dev/null || true
ln -sf ../lib32/Scrt1.o $SYSROOT/lib/Scrt1.o 2>/dev/null || true
ln -sf ../lib32/ld-linux.so.2 $SYSROOT/lib/ld-linux.so.2 2>/dev/null || true
echo "✓ Startup file and dynamic linker symlinks created"

#==============================================================================
# BUILD GMP, MPFR, MPC (64-bit and 32-bit to SYSROOT)
#==============================================================================

export GMP_MPFR_MPC_STAGING="$GC_INSTALL_DIR/gmp-mpfr-mpc-staging"
mkdir -p $GMP_MPFR_MPC_STAGING

echo "=========================================="
echo "Skipping GMP/MPFR/MPC to SYSROOT..."
echo "=========================================="
echo "Note: GMP/MPFR/MPC not needed in sysroot - only in staging for GCC build"
echo "✓ GMP, MPFR, MPC sysroot step skipped (not required)"

#==============================================================================
# BUILD GMP, MPFR, MPC TO STAGING (for GCC build)
#==============================================================================

echo "=========================================="
echo "Building GMP/MPFR/MPC to STAGING (for GCC build)..."
echo "=========================================="

cd $BUILD_DIR
rm -rf gmp-staging-build && mkdir gmp-staging-build && cd gmp-staging-build
CC=/usr/bin/gcc CFLAGS="-O2" \
$SOURCES_DIR/gmp/${GMP_VERSION}/configure --prefix=$GMP_MPFR_MPC_STAGING
make && make install

cd $BUILD_DIR
rm -rf mpfr-staging-build && mkdir mpfr-staging-build && cd mpfr-staging-build
CC=/usr/bin/gcc CFLAGS="-O2" \
$SOURCES_DIR/mpfr/${MPFR_VERSION}/configure \
    --prefix=$GMP_MPFR_MPC_STAGING \
    --with-gmp=$GMP_MPFR_MPC_STAGING
make && make install

cd $BUILD_DIR
rm -rf mpc-staging-build && mkdir mpc-staging-build && cd mpc-staging-build
CC=/usr/bin/gcc CFLAGS="-O2" \
$SOURCES_DIR/mpc/${MPC_VERSION}/configure \
    --prefix=$GMP_MPFR_MPC_STAGING \
    --with-gmp=$GMP_MPFR_MPC_STAGING \
    --with-mpfr=$GMP_MPFR_MPC_STAGING
make && make install

echo "✓ Staging libraries installed"

#==============================================================================
# BUILD FINAL GCC (MULTILIB)
#==============================================================================

echo "=========================================="
echo "Building Final GCC (Multilib - 32-bit + 64-bit)..."
echo "=========================================="

cd $BUILD_DIR
rm -rf gcc-final-build && mkdir gcc-final-build && cd gcc-final-build

CC="/usr/bin/gcc" \
CXX="/usr/bin/g++" \
$SOURCES_DIR/gcc/${GCC_VERSION}/configure \
    --prefix=$GC_INSTALL_DIR \
    --target=$TARGET_64_BIT \
    --build=$TARGET_64_BIT \
    --host=$TARGET_64_BIT \
    --with-sysroot=$SYSROOT \
    --with-native-system-header-dir=/usr/include \
    --with-gmp=$GMP_MPFR_MPC_STAGING \
    --with-mpfr=$GMP_MPFR_MPC_STAGING \
    --with-mpc=$GMP_MPFR_MPC_STAGING \
    --enable-languages=c,c++ \
    --enable-multilib \
    --with-multilib-list=m64,m32 \
    --enable-shared \
    --enable-threads=posix \
    --enable-__cxa_atexit \
    --enable-clocale=gnu \
    --enable-gnu-unique-object \
    --enable-linker-build-id \
    --with-linker-hash-style=gnu \
    --enable-plugin \
    --enable-lto \
    --enable-default-ssp \
    --disable-bootstrap \
    --disable-werror \
    --with-as=$GC_INSTALL_DIR/bin/as \
    --with-ld=$GC_INSTALL_DIR/bin/ld

make
make install

echo "✓ Final GCC Build Complete (Multilib)!"

export PATH="$GC_INSTALL_DIR/bin:$PATH"

#==============================================================================
# CREATE GCC WRAPPER SCRIPTS (for multilib)
#==============================================================================

echo "=========================================="
echo "Creating GCC multilib wrapper scripts..."
echo "=========================================="

# Copy the real GCC driver binaries from build directory
# (xgcc and xg++ are the actual GCC driver programs)
echo "Copying real GCC binaries from build directory..."
cp $BUILD_DIR/gcc-final-build/gcc/xgcc $GC_INSTALL_DIR/bin/gcc-real
cp $BUILD_DIR/gcc-final-build/gcc/xg++ $GC_INSTALL_DIR/bin/g++-real
chmod +x $GC_INSTALL_DIR/bin/gcc-real
chmod +x $GC_INSTALL_DIR/bin/g++-real
echo "✓ Real GCC binaries preserved as gcc-real and g++-real"

# Remove any existing gcc/g++ that may have been installed
rm -f $GC_INSTALL_DIR/bin/gcc $GC_INSTALL_DIR/bin/g++

# Create lib32 directory and symlinks for 32-bit C++ runtime libraries
# GCC multilib installs 32-bit libraries to lib/, but rpath expects them in lib32/
echo "Creating lib32 directory and symlinking C++ runtime libraries..."
mkdir -p $GC_INSTALL_DIR/lib32
ln -sf ../lib/libstdc++.so.6.0.34 $GC_INSTALL_DIR/lib32/libstdc++.so.6.0.34 2>/dev/null || true
ln -sf libstdc++.so.6.0.34 $GC_INSTALL_DIR/lib32/libstdc++.so.6 2>/dev/null || true
ln -sf libstdc++.so.6 $GC_INSTALL_DIR/lib32/libstdc++.so 2>/dev/null || true
ln -sf ../lib/libgcc_s.so.1 $GC_INSTALL_DIR/lib32/libgcc_s.so.1 2>/dev/null || true
ln -sf libgcc_s.so.1 $GC_INSTALL_DIR/lib32/libgcc_s.so 2>/dev/null || true
echo "✓ C++ runtime library symlinks created"

cat > $GC_INSTALL_DIR/bin/gcc << 'GCCWRAPPEREOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GCC_INSTALL="$(dirname "$SCRIPT_DIR")"
SYSROOT="$GCC_INSTALL/sysroot"

# Determine if -m32 is being used
IS_32BIT=0
for arg in "$@"; do
  if [ "$arg" = "-m32" ]; then
    IS_32BIT=1
    break
  fi
done

if [ $IS_32BIT -eq 1 ]; then
  # 32-bit compilation
  exec "$SCRIPT_DIR/gcc-real" --sysroot="$SYSROOT" -B"$SCRIPT_DIR" \
    -Wl,--dynamic-linker="$SYSROOT/lib/ld-linux.so.2" \
    -Wl,-rpath="$SYSROOT/lib32" \
    -Wl,-rpath="$GCC_INSTALL/lib32" "$@"
else
  # 64-bit compilation (default)
  exec "$SCRIPT_DIR/gcc-real" --sysroot="$SYSROOT" -B"$SCRIPT_DIR" \
    -Wl,--dynamic-linker="$SYSROOT/lib64/ld-linux-x86-64.so.2" \
    -Wl,-rpath="$SYSROOT/lib64" \
    -Wl,-rpath="$GCC_INSTALL/lib64" "$@"
fi
GCCWRAPPEREOF

cat > $GC_INSTALL_DIR/bin/g++ << 'GPPWRAPPEREOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GCC_INSTALL="$(dirname "$SCRIPT_DIR")"
SYSROOT="$GCC_INSTALL/sysroot"

# Determine if -m32 is being used
IS_32BIT=0
for arg in "$@"; do
  if [ "$arg" = "-m32" ]; then
    IS_32BIT=1
    break
  fi
done

if [ $IS_32BIT -eq 1 ]; then
  # 32-bit compilation
  exec "$SCRIPT_DIR/g++-real" --sysroot="$SYSROOT" -B"$SCRIPT_DIR" \
    -Wl,--dynamic-linker="$SYSROOT/lib/ld-linux.so.2" \
    -Wl,-rpath="$SYSROOT/lib32" \
    -Wl,-rpath="$GCC_INSTALL/lib32" "$@"
else
  # 64-bit compilation (default)
  exec "$SCRIPT_DIR/g++-real" --sysroot="$SYSROOT" -B"$SCRIPT_DIR" \
    -Wl,--dynamic-linker="$SYSROOT/lib64/ld-linux-x86-64.so.2" \
    -Wl,-rpath="$SYSROOT/lib64" \
    -Wl,-rpath="$GCC_INSTALL/lib64" "$@"
fi
GPPWRAPPEREOF

chmod +x $GC_INSTALL_DIR/bin/gcc
chmod +x $GC_INSTALL_DIR/bin/g++

echo "✓ GCC multilib wrapper scripts created"

#==============================================================================
# VERIFICATION
#==============================================================================

echo "=========================================="
echo "VERIFICATION - MULTILIB TESTING"
echo "=========================================="

echo "GCC version:"
$GC_INSTALL_DIR/bin/gcc --version

echo ""
echo "=========================================="
echo "Testing 64-bit C program:"
echo "=========================================="
cat > /tmp/test64.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello from 64-bit C!\n");
    printf("Pointer size: %zu bytes\n", sizeof(void*));
    return 0;
}
EOF

$GC_INSTALL_DIR/bin/gcc -m64 /tmp/test64.c -o /tmp/test64
/tmp/test64

echo ""
echo "Checking 64-bit dependencies:"
ldd /tmp/test64

echo ""
echo "=========================================="
echo "Testing 32-bit C program:"
echo "=========================================="
cat > /tmp/test32.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello from 32-bit C!\n");
    printf("Pointer size: %zu bytes\n", sizeof(void*));
    return 0;
}
EOF

$GC_INSTALL_DIR/bin/gcc -m32 /tmp/test32.c -o /tmp/test32
/tmp/test32

echo ""
echo "Checking 32-bit dependencies:"
ldd /tmp/test32

echo ""
echo "=========================================="
echo "Testing 64-bit C++ program:"
echo "=========================================="
cat > /tmp/testcpp64.cpp << 'EOF'
#include <iostream>
int main() {
    std::cout << "Hello from 64-bit C++!" << std::endl;
    std::cout << "Pointer size: " << sizeof(void*) << " bytes" << std::endl;
    return 0;
}
EOF

$GC_INSTALL_DIR/bin/g++ -m64 /tmp/testcpp64.cpp -o /tmp/testcpp64
/tmp/testcpp64

echo ""
echo "Checking 64-bit C++ dependencies:"
ldd /tmp/testcpp64

echo ""
echo "=========================================="
echo "Testing 32-bit C++ program:"
echo "=========================================="
cat > /tmp/testcpp32.cpp << 'EOF'
#include <iostream>
int main() {
    std::cout << "Hello from 32-bit C++!" << std::endl;
    std::cout << "Pointer size: " << sizeof(void*) << " bytes" << std::endl;
    return 0;
}
EOF

$GC_INSTALL_DIR/bin/g++ -m32 /tmp/testcpp32.cpp -o /tmp/testcpp32
/tmp/testcpp32

echo ""
echo "Checking 32-bit C++ dependencies:"
ldd /tmp/testcpp32

#==============================================================================
# SUCCESS
#==============================================================================

echo ""
echo "=========================================="
echo "BUILD COMPLETE!"
echo "=========================================="
echo ""
echo "Self-contained GCC MULTILIB toolchain installed at:"
echo "  $GC_INSTALL_DIR"
echo ""
echo "Sysroot structure:"
echo "  - 64-bit libraries: $SYSROOT/lib64/"
echo "  - 32-bit libraries: $SYSROOT/lib32/"
echo "  - Headers: $SYSROOT/usr/include/"
echo ""
echo "Usage:"
echo "  export PATH=\"$GC_INSTALL_DIR/bin:\$PATH\""
echo "  gcc -m64 program.c -o program64  # 64-bit compilation"
echo "  gcc -m32 program.c -o program32  # 32-bit compilation"
echo ""
echo "Package size:"
du -sh $GC_INSTALL_DIR
echo "=========================================="
