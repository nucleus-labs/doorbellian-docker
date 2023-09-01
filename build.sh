#!/usr/bin/env bash


export  FORCE_UNSAFE_CONFIGURE=1
source  build/envsetup.sh   \
    &&  lunch 1             \
    &&  make -j1            \
    &&  mboot               \
    &&  pack

