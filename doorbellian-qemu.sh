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

if [ $# -ne 2 ]; then
    echo "Usage: $0 <usb_hostbus> <usb_hostaddr>"
    exit 1
fi

host_bus=$1
host_addr=$2

# todo: loop over usb arguments and construct a device argument for each pair?
# @rummik will need to investigate
usb_devices="-device usb-host,bus=usb.0,hostbus=${host_bus},hostaddr=${host_addr}"

cleanup() {
    # Find USB video or media devices in sysfs
    usb_device_paths=$(grep -E 'video[0-9]+|media[0-9]+' /sys/bus/usb/devices/*/modalias | cut -d '/' -f 6)

    for device_path in $usb_device_paths; do
        # Find the USB device bus and port numbers
        usb_bus=$(basename $(dirname /sys/bus/usb/devices/${device_path}))
        usb_port=$(basename $(dirname $(dirname /sys/bus/usb/devices/${device_path})))

        # Unbind the USB device from the virtual USB hub
        echo 1 | sudo tee /sys/bus/usb/devices/${usb_bus}-${usb_port}/detach

        # Rebind the USB device to the host USB controller
        echo "${usb_bus}-${usb_port}" | sudo tee /sys/bus/usb/drivers/usb/bind
    done
}

trap 'cleanup' SIGTERM

qemu-system-riscv64 \
    -nographic \
    -machine virt \
    -kernel linux.Image \
    -append "root=/dev/vda rw console=ttyS0" \
    -drive file=busybox-disk,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    \
    -device nec-usb-xhci,id=usb \
    ${usb_devices} \
    \
    -device virtio-net-device,netdev=eth0 \
    -netdev user,id=eth0,hostfwd=tcp::1935-:1935,hostfwd=tcp::8000-:8000,hostfwd=tcp::8001-:8001,hostfwd=tcp::8554-:8554,hostfwd=tcp::8888-:8888,hostfwd=tcp::8889-:8889 \
    &

wait $!
