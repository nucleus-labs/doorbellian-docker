#!/usr/bin/env bash


export  FORCE_UNSAFE_CONFIGURE=1
source  build/envsetup.sh
lunch   d1_mq_pro-tina

mkdir -p /artifacts/tina/in
# cp .config /artifacts/tina/in/.config

make ARCH=riscv SOURCE_DATE_EPOCH=$(date +%s) TAR_CMD="\$(HOST_TAR) --no-same-owner -C \$(1)/.. \$(TAR_OPTIONS)" -j${JOBS}

cp .config /artifacts/tina/in/.config
