#!/usr/bin/env bash


export  FORCE_UNSAFE_CONFIGURE=1
source  build/envsetup.sh
lunch d1_mq_pro-tina

make ARCH=riscv .config
make ARCH=riscv -j${JOBS}
