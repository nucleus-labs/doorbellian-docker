
description="initialize doorbellian-docker"


# (1:directory; 2:filename; 3:gdrive id)
function gdown () {
    local filedir=$1
    local filename=$2
    local id=$3

    echo "${id}:$(pwd)/${filedir}/${filename}" >&2

    local confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "https://docs.google.com/uc?export=download&id=${id}" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=${confirm}&id=${id}" -O "${filename}"
    mv ${filename} ${filedir}/${filename}
    rm -rf /tmp/cookies.txt
}

function target_init () {
    [[ ! -d linux-tina ]] && git submodule update --init --recursive

    if [[ ! -f deps/build/tina/prebuilt.tar.gz ]]; then
        gdown deps/build/tina prebuilt.tar.gz 1uNUZuIhyTTonpgTIUTCfyRp72zqgU4ZD
    elif [[ $(sha256sum deps/build/tina/prebuilt.tar.gz | cut -d' ' -f1) != "d410bfb02c0dd20a21a5707bdabe5abf0b4cb535f2b9492b51d2bf6d6d601687" ]]; then
        echo "deps/build/tina/prebuilt.tar.gz hash was bad! Fetching..."
        rm deps/build/tina/prebuilt.tar.gz
        gdown deps/build/tina prebuilt.tar.gz 1uNUZuIhyTTonpgTIUTCfyRp72zqgU4ZD
    fi

    if [[ ! -f deps/build/tina/dl.tar ]]; then
        gdown deps/build/tina dl.tar 1EoHjRQs2T8Krn5uBBsFNpPnrLUdW1RpD
    elif [[ $(sha256sum deps/build/tina/dl.tar | cut -d' ' -f1) != "3100c2c8751a1ad3d59f9f188ece84c7c0aa1022aa6564fe80405a30c01a7032" ]]; then
        echo "deps/build/tina/dl.tar hash was bad! Fetching..."
        rm deps/build/tina/dl.tar
        gdown deps/build/tina dl.tar 1EoHjRQs2T8Krn5uBBsFNpPnrLUdW1RpD
    fi
    

    if [[ ! -f deps/build/tina/riscv64-linux-x86_64-20200528.tar.xz ]]; then
        gdown deps/build/tina riscv64-linux-x86_64-20200528.tar.xz 1MhCcR57cplFo2dSA1HU97kbS5trWzZXP
    elif [[ $(sha256sum deps/build/tina/riscv64-linux-x86_64-20200528.tar.xz | cut -d' ' -f1) != "413481f8eeec0ff29adc65660110a00e01c22b0948c4cda211d4f7d28a0bd53c" ]]; then
        echo "deps/build/tina/riscv64-linux-x86_64-20200528.tar.xz hash was bad! Fetching..."
        rm deps/build/tina/riscv64-linux-x86_64-20200528.tar.xz
        gdown deps/build/tina riscv64-linux-x86_64-20200528.tar.xz 1MhCcR57cplFo2dSA1HU97kbS5trWzZXP
    fi

    if [[ ! -f deps/build/tina/gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabi.tar.xz ]]; then
        gdown deps/build/tina gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabi.tar.xz 1K1fgQQSLfcWVxAeKBJ6YOBeFCgg9_nct
    elif [[ $(sha256sum deps/build/tina/gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabi.tar.xz | cut -d' ' -f1) != "89e9bfc7ffe615f40a72c2492df0488f25fc20404e5f474501c8d55941337f71" ]]; then
        echo "deps/build/tina/gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabi.tar.xz hash was bad! Fetching..."
        rm deps/build/tina/gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabi.tar.xz
        gdown deps/build/tina gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabi.tar.xz 1K1fgQQSLfcWVxAeKBJ6YOBeFCgg9_nct
    fi

    mkdir -p deps/build/mediamtx
    [[ ! -f deps/build/mediamtx/go1.20.5.linux-amd64.tar.gz ]] && {
        wget -O go1.20.5.linux-amd64.tar.gz https://go.dev/dl/go1.20.5.linux-amd64.tar.gz
        mv go1.20.5.linux-amd64.tar.gz deps/build/mediamtx/go1.20.5.linux-amd64.tar.gz
    }
}
