#!/bin/bash
#
# 克隆代码
# git clone -b lineage-17.1 git@github.com:HKL-Kevin/android_kernel_xiaomi_msm8998.git --depth=1
#
sudo apt update
sudo apt install build-essential openssl pkg-config libssl-dev libncurses5-dev pkg-config minizip libelf-dev flex bison  libc6-dev libidn11-dev rsync bc liblz4-tool
sudo apt install gcc-aarch64-linux-gnu dpkg-dev dpkg git


export ARCH=arm64
export SUBARCH=arm64

export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export LLVM=1
export LLVM_IAS=1

sudo apt install -y gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu

rm -rf out
make O=out sagit_defconfig
make O=out menuconfig
make O=out savedefconfig
make O=out KCFLAGS="-Wno-error" -j$(nproc)
