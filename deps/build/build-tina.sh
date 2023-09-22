#!/usr/bin/env bash


export  FORCE_UNSAFE_CONFIGURE=1
source  build/envsetup.sh           \
    &&  lunch 1                     \
    &&  make ARCH=riscv64 .config   \
    &&  make ARCH=riscv64 -j${JOBS}
#     &&  mboot                   \
#     &&  pack

