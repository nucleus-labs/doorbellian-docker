FROM ubuntu:22.04 AS FETCH_STAGE

RUN     apt-get update          \
    &&  apt-get upgrade         \
    &&  apt-get install -y      \
            git                 \
            wget                \
            xz-utils

WORKDIR /sources

RUN     wget http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.25.0.tar.xz   \
    &&  tar -xf crosstool-ng-1.25.0.tar.xz                                              \
    &&  rm crosstool-ng-1.25.0.tar.xz
RUN     git clone --depth=1 -b v6.4 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
RUN     git clone --depth=1 -b 1_36_stable git://busybox.net/busybox
RUN     wget https://go.dev/dl/go1.20.5.linux-amd64.tar.gz                              \
    &&  tar -xzf go1.20.5.linux-amd64.tar.gz                                            \
    &&  rm go1.20.5.linux-amd64.tar.gz
RUN     git clone --depth=1 -b release/6.0 https://git.ffmpeg.org/ffmpeg
RUN     git clone https://github.com/bluenviron/mediamtx                                \
    &&  cd mediamtx                                                                     \
    &&  git checkout 91ada9bf07487371f2c0189ab73201ddbaef468e



FROM ubuntu:22.04 AS BUILD_STAGE

ENV     DEBIAN_FRONTEND=noninteractive
RUN     apt-get update              \
    &&  apt-get upgrade
RUN     apt-get install -y          \
            build-essential         \
            device-tree-compiler    \
            flex                    \
            bison                   \
            bc                      \
            git                     \
	        texinfo		            \
	        pkg-config		        \
            help2man                \
            libtool-bin             \
            unzip                   \
            gawk                    \
            libncurses5-dev         \
            wget                    \
            curl                    \
            rsync                   \
            python3

RUN     useradd -m iris
USER    iris
RUN     mkdir -p /home/iris/builds
WORKDIR /home/iris/builds

COPY    --from=FETCH_STAGE  /sources/crosstool-ng-1.25.0    /home/iris/builds/crosstool-ng-1.25.0

USER    root

RUN     cd crosstool-ng-1.25.0              \
    &&  ./configure --prefix=/opt/cross     \
    &&  make    			                \
    &&  make install
ENV PATH=$PATH:/opt/cross/bin

USER    iris

RUN mkdir ctng
ADD ct-ng.config ctng/.config

RUN     cd ctng                             \
    &&  ct-ng source
RUN     cd ctng                             \
    &&  ct-ng build

USER    root


COPY --from=FETCH_STAGE /sources/linux      /home/iris/builds/linux

ENV PATH="$PATH:/home/iris/x-tools/riscv64-nucleus_labs-linux-gnu/bin"
ENV CCPREFIX="/home/iris/x-tools/riscv64-nucleus_labs-linux-gnu/bin/riscv64-nucleus_labs-linux-gnu-"
ENV CROSS_COMPILE=riscv64-nucleus_labs-linux-gnu-
# ENV LDFLAGS=--static


# RUN gcc -E -x assembler-with-cpp -undef \
#     -Ilinux/include \
#     -o sun20i-d1-mangopi-mq-pro.dts.pp \
#     linux/arch/riscv/boot/dts/allwinner/sun20i-d1-mangopi-mq-pro.dts
# RUN dtc -I dts -O dtb \
#     -o sun20i-d1-mangopi-mq-pro.dtb \
#     sun20i-d1-mangopi-mq-pro.dts.pp

RUN     cd linux \
    &&  make ARCH=riscv defconfig \
    &&  make ARCH=riscv


COPY --from=FETCH_STAGE /sources/busybox    /home/iris/builds/busybox

RUN     cd busybox \
    &&  make defconfig \
    &&  make

RUN     mkdir rootfs \
    &&  make -C busybox install CONFIG_PREFIX=../rootfs


COPY --from=FETCH_STAGE /sources/go         /usr/local
ENV PATH=$PATH:/usr/local/go/bin

COPY    --from=FETCH_STAGE  /sources/ffmpeg     /home/iris/builds/ffmpeg

RUN     cd ffmpeg                                           \
    &&  ./configure                                         \
            --arch=riscv64                                  \
            --target-os=linux                               \
            --cross-prefix=${CCPREFIX}                      \
            --prefix=/home/iris/builds/ffmpeg/build         \
    &&  make

# RUN     find / -name ffmpeg -type f

COPY    --from=FETCH_STAGE  /sources/mediamtx   /home/iris/builds/mediamtx

ENV GOOS=linux
ENV GOARCH=riscv64
ENV CGO_ENABLED=1
ENV CC=riscv64-nucleus_labs-linux-gnu-gcc
RUN     cd mediamtx             \
    &&  go build .



FROM ubuntu:22.04 AS DISK_STAGE

WORKDIR /disk
COPY --from=BUILD_STAGE     /home/iris/builds/busybox               busybox
COPY --from=BUILD_STAGE     /home/iris/builds/mediamtx/mediamtx     mediamtx
COPY --from=BUILD_STAGE     /home/iris/builds/rootfs                rootfs
ADD                         mediamtx.yml                            mediamtx.yml
ADD                         startup.sh                              startup.sh

# generate virtual disk and populate with rootfs
RUN     dd if=/dev/zero of=busybox-disk bs=1M count=1024        \
    &&  mkdir -p rootfs/proc rootfs/sys rootfs/dev rootfs/etc   \
    &&  touch rootfs/etc/fstab                                  \
    &&  mkdir -p rootfs/etc/init.d                              \
    &&  cp startup.sh rootfs/etc/init.d/rcS                     \
    &&  cp mediamtx rootfs/bin/mediamtx                         \
    &&  cp mediamtx.yml rootfs/etc/mediamtx.yml                 \
    &&  chmod +x rootfs/etc/init.d/rcS                          \
    &&  mkfs.ext4 busybox-disk -d rootfs


FROM ubuntu:22.04 AS RUN_STAGE

WORKDIR /doorbellian

RUN     apt-get update              \
    &&  apt-get install -y          \
            qemu-system-riscv64     \
            v4l-utils               \
            usbutils

COPY --from=DISK_STAGE  /disk/busybox-disk                                busybox-disk
COPY --from=BUILD_STAGE /home/iris/builds/linux/arch/riscv/boot/Image     linux.Image
# COPY --from=BUILD_STAGE /builds/sun20i-d1-mangopi-mq-pro.dtb    \
#     sun20i-d1-mangopi-mq-pro.dtb

ADD doorbellian-qemu.sh doorbellian-qemu.sh
RUN chmod +x doorbellian-qemu.sh

CMD ["/doorbellian/doorbellian-qemu.sh"]
# CMD ["/bin/bash"]
