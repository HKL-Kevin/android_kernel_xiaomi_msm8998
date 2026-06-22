#!/bin/bash
set -euo pipefail

# =========================
# Config
# =========================
WORKDIR=~/reKernel
KERNEL_SRC=~/android_kernel_xiaomi_msm8998
OUT_DIR="$KERNEL_SRC/out"
BOOTIMG="$WORKDIR/boot.img"
NEW_BOOTIMG="$WORKDIR/new_boot.img"
KERNEL_GZ="$OUT_DIR/arch/arm64/boot/Image.gz"
LOG_FILE="build.log"

# =========================
# Utils
# =========================
log() {
    echo -e "\n[$(date +%H:%M:%S)] $*"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_file() {
    [[ -f "$1" ]] || die "Missing file: $1"
}

# =========================
# Dependencies
# =========================
install_deps() {
    log "Installing dependencies"
    sudo apt update
    sudo apt install -y \
        build-essential bc bison flex \
        libssl-dev libncurses5-dev libelf-dev \
        liblz4-tool libidn11-dev rsync \
        gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
        git dpkg-dev time ccache
}

# =========================
# Ccache setup
# =========================
setup_ccache() {
    log "Configuring ccache"
    export USE_CCACHE=1
    export CCACHE_SLOPPINESS=include_file_mtime,include_file_ctime,file_macro,time_macros
    export CCACHE_NOHASHDIR=true
    export CCACHE_DIR="$HOME/.ccache"
    ccache -M 20G >/dev/null
}

# =========================
# Build env
# =========================
setup_env() {
    export ARCH=arm64
    export SUBARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

    export KCFLAGS="-O2"
    export KBUILD_BUILD_TIMESTAMP=""
    export KBUILD_BUILD_USER="kevin"
    export KBUILD_BUILD_HOST="ubuntu"
}

# =========================
# Kernel build
# =========================
build_kernel() {
    log "Clean build"
    make -C "$KERNEL_SRC" O=out clean

    log "Defconfig"
    make -C "$KERNEL_SRC" O=out ARCH=arm64 sagit_defconfig

    log "Compile kernel"

    /usr/bin/time -f "\nTime: %E\nCPU: %P\nMem: %M KB" \
    make -C "$KERNEL_SRC" O=out -j"$(nproc)" \
        CC="ccache aarch64-linux-gnu-gcc" \
        KCFLAGS="-w" \
        2>&1 | tee "$LOG_FILE"
}

# =========================
# Replace kernel in boot.img
# =========================
replace_kernel() {
    log "Switch to workdir"
    cd "$WORKDIR"

    require_file "$BOOTIMG"
    require_file "$KERNEL_GZ"

    log "Backup boot.img"
    cp -f boot.img boot.img.bak

    log "Cleanup"
    magiskboot cleanup

    log "Unpack boot.img"
    magiskboot unpack -h boot.img

    log "Decompress kernel"
    gunzip -c "$KERNEL_GZ" > kernel.new

    log "Replace kernel"
    cp -f kernel.new kernel

    log "Repack boot.img"
    magiskboot repack boot.img new_boot.img

    log "Verify image"
    magiskboot verify new_boot.img

    cd - >/dev/null
}

# =========================
# Stats
# =========================
print_stats() {
    log "ccache stats"
    ccache -s | tail -n 10

    log "Build log: $LOG_FILE"
}

# =========================
# Main
# =========================
main() {
    START=$(date +%s)

    log "Start build pipeline"

    install_deps
    setup_ccache
    setup_env
    build_kernel
    replace_kernel
    print_stats

    END=$(date +%s)
    DURATION=$((END - START))

    log "DONE"
    echo "Total: ${DURATION}s"
    printf "Time: %02d:%02d:%02d\n" \
        $((DURATION/3600)) $((DURATION%3600/60)) $((DURATION%60))
}

main "$@"
