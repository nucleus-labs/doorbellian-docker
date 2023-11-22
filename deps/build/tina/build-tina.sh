#!/usr/bin/env bash


export  FORCE_UNSAFE_CONFIGURE=1
source  build/envsetup.sh
lunch d1_mq_pro-tina

make ARCH=riscv TAR_CMD="\$(HOST_TAR) --no-same-owner -C \$(1)/.. \$(TAR_OPTIONS)" -j$(( ${JOBS} + 1 ))
