

description="list found camera devices"

function target_usb () {
    usb_init

    echo ==============================================================
    echo -e "${cam_output}"
    echo ==============================================================
    echo -e "${lsusb_output}"
    echo ==============================================================

    # Print the extracted IDs
    echo "Extracted Device IDs:    ${ids//|/,}"
    echo "Extracted USB Bus IDs:   ${bus_ids}"
    echo "Extracted USB Addresses: ${bus_addrs}"
    echo "Extracted USB List:      ${usb_list[@]}"

    echo ==============================================================

    validate_usb_devices
    [[ ${force} -eq 0 ]] && echo "found USB devices are all valid!"
}

