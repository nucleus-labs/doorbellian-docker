#!/bin/bash
# set -x


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

if [ $# -eq 0 ]; then
    echo "Usage: $0 [<usb_hostbus>,<usb_hostaddr> ...]"
    exit 1
fi

usb_list=($@)

# loop over usb arguments and construct a device argument for each pair
usb_devices=""
for usb_device in ${usb_list[@]}; do
    # Split the USB device ID into bus and address
    host_bus=$(echo ${usb_device} | cut -d ',' -f 1)
    host_addr=$(echo ${usb_device} | cut -d ',' -f 2)

    # Add the USB device to the list of devices
    usb_devices="${usb_devices} -device usb-host,bus=usb.0,hostbus=${host_bus},hostaddr=${host_addr}"
done

DTB=/artifacts/tina/dts/board.dtb

IMG_PREFIX=/artifacts/tina/out
BOOT_IMG=boot.img
KERNEL_IMG=d1-mq_pro-uImage
DISK_IMG=rootfs.img

qemu-system-riscv64 \
    -nographic \
    -machine virt \
    -kernel ${IMG_PREFIX}/${KERNEL_IMG} \
    -append "root=/dev/vda rw console=ttyS0" \
    -drive file=${IMG_PREFIX}/${DISK_IMG},format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    \
    -device nec-usb-xhci,id=usb \
    ${usb_devices} \
    \
    -device virtio-net-device,netdev=eth0 \
    -netdev user,id=eth0,hostfwd=tcp::1935-:1935,hostfwd=tcp::8000-:8000,hostfwd=tcp::8001-:8001,hostfwd=tcp::8554-:8554,hostfwd=tcp::8888-:8888,hostfwd=tcp::8889-:8889

# wait $!
