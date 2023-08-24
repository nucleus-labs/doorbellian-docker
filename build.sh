#!/usr/bin/env bash

(source build/envsetup.sh 2>&1 | tee build.tina) && (lunch 1 2>&1 | tee build.tina)
export FORCE_UNSAFE_CONFIGURE=1
make -j10 2>&1 | tee build.tina

