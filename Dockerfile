FROM ubuntu:22.04 AS CLONE_STAGE

RUN     apt-get update          \
    &&  apt-get upgrade         \
    &&  apt-get install -y      \
            git                 \
            wget

WORKDIR /sources

# Fetch stage
RUN git clone --depth=1 -b v6.4 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
RUN git clone --depth=1 -b 1_36_stable git://busybox.net/busybox
RUN wget https://go.dev/dl/go1.20.5.linux-amd64.tar.gz          \
    &&  tar -xzf go1.20.5.linux-amd64.tar.gz                    \
    &&  rm go1.20.5.linux-amd64.tar.gz
RUN git clone https://github.com/bluenviron/mediamtx            \
    &&  cd mediamtx                                             \
    &&  git checkout 91ada9bf07487371f2c0189ab73201ddbaef468e



FROM ubuntu:22.04 AS BUILD_STAGE

WORKDIR /builds

COPY --from=CLONE_STAGE /sources/linux      /builds/linux

ENV     DEBIAN_FRONTEND=noninteractive
RUN     apt-get update              \
    &&  apt-get upgrade
RUN     apt-get install -y          \
            build-essential         \
            device-tree-compiler    \
            flex                    \
            bison                   \
            gcc-riscv64-linux-gnu   \
            bc                      \
            git                     \
            ca-certificates         \
    &&  update-ca-certificates

ENV LDFLAGS=--static
ENV CROSS_COMPILE=riscv64-linux-gnu-

# RUN gcc -E -x assembler-with-cpp -undef \
#     -Ilinux/include \
#     -o sun20i-d1-mangopi-mq-pro.dts.pp \
#     linux/arch/riscv/boot/dts/allwinner/sun20i-d1-mangopi-mq-pro.dts
# RUN dtc -I dts -O dtb \
#     -o sun20i-d1-mangopi-mq-pro.dtb \
#     sun20i-d1-mangopi-mq-pro.dts.pp

RUN     cd linux \
    &&  make ARCH=riscv defconfig \
    &&  make ARCH=riscv -j8


COPY --from=CLONE_STAGE /sources/busybox    /builds/busybox

RUN     cd busybox \
    &&  LDFLAGS=--static make defconfig \
    &&  LDFLAGS=--static make -j8

RUN     mkdir rootfs \
    &&  make -C busybox install CONFIG_PREFIX=../rootfs


COPY --from=CLONE_STAGE /sources/go         /usr/local
ENV PATH=$PATH:/usr/local/go/bin


COPY --from=CLONE_STAGE /sources/mediamtx   /builds/mediamtx

ENV GOOS=linux
ENV GOARCH=riscv64
ENV CGO_ENABLED=0
ENV CC=riscv64-linux-gnu-gcc
RUN     cd mediamtx             \
    &&  go build .



FROM ubuntu:22.04 AS DISK_STAGE

WORKDIR /disk
COPY --from=BUILD_STAGE     /builds/busybox             busybox
COPY --from=BUILD_STAGE     /builds/mediamtx/mediamtx   mediamtx
COPY --from=BUILD_STAGE     /builds/rootfs              rootfs
ADD                         mediamtx.yml                mediamtx.yml
ADD                         startup.sh                  startup.sh

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
            qemu-system-riscv64

COPY --from=DISK_STAGE  /disk/busybox-disk                      busybox-disk
COPY --from=BUILD_STAGE /builds/linux/arch/riscv/boot/Image     linux.Image
# COPY --from=BUILD_STAGE /builds/sun20i-d1-mangopi-mq-pro.dtb    \
#     sun20i-d1-mangopi-mq-pro.dtb

ADD doorbellian-qemu.sh doorbellian-qemu.sh
RUN chmod +x doorbellian-qemu.sh

CMD ["/doorbellian/doorbellian-qemu.sh"]
# CMD ["/bin/bash"]
