
dockerfile="modes/Dockerfile.raspbian"
image_tag="rpi"

if [[ ! -f deps/build/raspbian/2023-12-11-raspios-bookworm-armhf-lite.img ]]; then
    echo "raspberry pi os image missing! fetch? [Y/n]"
    local _fetch
    read _fetch
    if [[ x"${_fetch}" == x"" || x"${_fetch}" == x"y" || x"${_fetch}" == x"Y" ]]; then
        if [[ ! -v VM_HOSTNAME || ! -v VM_USERNAME || ! -v VM_PASSWORD ]]; then
            [[ x"$(grep 'VM_HOSTNAME' .env)" == x"" ]] && echo -e "VM_HOSTNAME=\n" >> .env
            [[ x"$(grep 'VM_USERNAME' .env)" == x"" ]] && echo -e "VM_USERNAME=\n" >> .env
            [[ x"$(grep 'VM_PASSWORD' .env)" == x"" ]] && echo -e "VM_PASSWORD=\n" >> .env
            error $(eval echo "${ERR_INFO}") "One of VM Variables 'VM_HOSTNAME', 'VM_USERNAME', or 'VM_PASSWORD' are not set. Please enter values for them in the .env file"
        fi

        cd deps/build/raspbian/

        wget -O - https://downloads.raspberrypi.com/raspios_lite_armhf/images/raspios_lite_armhf-2023-12-11/2023-12-11-raspios-bookworm-armhf-lite.img.xz \
            | xz -d > "2023-12-11-raspios-bookworm-armhf-lite.img"

        # sudo -- ${SHELL} -c <<EOF
        local offset=$(fdisk -l "2023-12-11-raspios-bookworm-armhf-lite.img" | grep Linux | awk '{print $2}')
        offset=$(( ${offset} * 512 ))

        sudo mkdir -p /mnt/raspbian
        sudo mount -v -o offset=${offset} -t ext4 "2023-12-11-raspios-bookworm-armhf-lite.img" /mnt/raspbian

        sudo echo "${VM_HOSTNAME}" > /mnt/raspbian/etc/hostname
        sudo useradd -m -s /bin/bash -R /mnt/raspbian/ ${VM_USERNAME} -p $(mkpasswd ${VM_PASSWORD}) -G sudo

        sudo umount /mnt/raspbian
        sudo rm -rf /mnt/raspbian
# EOF

        cd ../../..
    fi
fi
