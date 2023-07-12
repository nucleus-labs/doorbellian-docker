#!/bin/bash


# qemu-system-riscv64                             \
#     -machine virt                               \
#                                                 \
#     -nographic                                  \
#     -m size=1G                                  \
#                                                 \
#     -drive  file=busybox-disk,format=raw,id=hd0 \
#     -device virtio-blk-device,drive=hd0         \
#                                                 \
#     -netdev user,id=eth0                        \
#     -device virtio-net-device,netdev=eth0       \
#                                                 \
#     -bios   none                                \
#     -kernel ${linux_kernel_image}               \
#     -append "console=ttyS0"                     \
#     -dtb    ./sun20i-d1-mangopi-mq-pro.dtb

qemu-system-riscv64 \
    -nographic \
    -machine virt \
    -kernel linux.Image \
    -append "root=/dev/vda rw console=ttyS0" \
    -drive file=busybox-disk,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    \
    -device virtio-net-device,netdev=eth0 \
    -netdev user,id=eth0,hostfwd=tcp::1935-:1935,hostfwd=tcp::8000-:8000,hostfwd=tcp::8001-:8001,hostfwd=tcp::8554-:8554,hostfwd=tcp::8888-:8888,hostfwd=tcp::8889-:8889
