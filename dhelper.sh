#!/usr/bin/env bash
# set -x

# ================================================================================================

valid_targets=("build" "run" "bar" "bash" "usb")
valid_target_found=0
container_cmd=./doorbellian-qemu.sh
target=$1
shift
container_args="$*"

# ================================================================================================

# check if the supplied target is valid
for value in "${valid_targets[@]}"; do
    if [ "$target" = "$value" ]; then
        valid_target_found=1
        break
    fi
done

# if no valid target matching the supplied target is found, error
if [ $valid_target_found -eq 0 ]; then
    echo "Error: '$target' is not a valid target."
    echo "Usage: $0 <$(IFS=/; echo "${valid_targets[*]}")>"
    exit 2
fi

# ================================================================================================

# Store video devices
cam_output=$(cam -l 2>/dev/null)

# Find device entries like "UVC Camera (046d:0825) (usb-0000:00:14.0-3)"

ids=$(echo "$cam_output" | grep -oE '[0-9a-f]{4}:[0-9a-f]{4}' | uniq)
ids=$(echo -n "$ids" | tr "\n" "|")

# highlight the device IDs in pink
cam_output=$(echo "$cam_output" | sed -E "s@($ids)@\o033[45;30m&\o033[0m@g")

lsusb_output=$(lsusb)


bus_ids=$(echo "$lsusb_output" | sed -En "s/Bus ([0-9]{3}) Device ([0-9]{3}): ID ($ids).*/\1/p" | awk '{ printf "%d,", $1 }' | head -c -1)
bus_addrs=$(echo "$lsusb_output" | sed -En "s/Bus ([0-9]{3}) Device ([0-9]{3}): ID ($ids).*/\2/p" | awk '{ printf "%d,", $1 }' | head -c -1)

lsusb_output=$(echo "$lsusb_output" | sed -E "s/Bus ([0-9]{3}) Device ([0-9]{3}): ID ($ids)/Bus \x1b[46;30m\1\x1b[0m Device \x1b[42;30m\2\x1b[0m: ID \3/g")
lsusb_output=$(echo "$lsusb_output" | sed -E "s@($ids)@\o033[45;30m&\o033[0m@g")

# declare -A usb_list
# for ((i=0; i<${#bus_ids[@]}; i++)); do
#     usb_list=${ids[$i]}
# done

# Split variables into arrays based on comma (,)
IFS=',' read -ra a_array <<< "$bus_ids"
IFS=',' read -ra b_array <<< "$bus_addrs"

usb_list=()
for ((i=0; i<${#a_array[@]}; i++)); do
    # Find the ID from the match
    echo $i
    usb_list=(${usb_list} ${a_array[$i]},${b_array[$i]})
done


if [ "$target" = "usb" ]; then
    echo ==============================================================
    echo -e "$cam_output"
    echo ==============================================================
    echo -e "$lsusb_output"
    echo ==============================================================

    # Print the matches
    echo "$matches"

    # Print the extracted IDs
    echo "Extracted Device IDs:    ${ids//|/,}"
    echo "Extracted USB Bus IDs:   ${bus_ids}"
    echo "Extracted USB Addresses: ${bus_addrs}"
    echo "Extracted USB List:      ${usb_list[@]}"

    echo ==============================================================
fi

if [ "$target" = "build" ] || [ "$target" = "bar" ]; then
    docker build -t doorbellian:dev .
fi

if [ "$target" = "run" ] || [ "$target" = "bar" ] || [ "$target" = "bash" ]; then

    if [ "$target" = "bash" ]; then
        container_cmd="/bin/bash"
    else
        container_args="${usb_list[@]}"
    fi

    device_args=""
    for dev in $(ls /dev/{video,media}* 2>/dev/null); do
        device_args="$device_args --device=$dev"
    done

    if [[ -z "$device_args" ]]; then
        echo "No video devices found."
        exit 3
    fi

    docker run -it --rm \
        --privileged \
        \
        --device=/dev/bus/usb:/dev/bus/usb \
        $device_args \
        \
        -p 1935:1935 \
        -p 8000:8000 \
        -p 8001:8001 \
        -p 8554:8554 \
        -p 8888:8888 \
        -p 8889:8889 \
        \
        doorbellian:dev $container_cmd $container_args

    
fi


