#!/bin/sh

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
v4l2_output=$(v4l2-ctl --list-devices)

# Find device entries like "UVC Camera (046d:0825) (usb-0000:00:14.0-3)"

matches=$(echo "$v4l2_output" | grep -oE '\([0-9a-fA-F:]+\)')
ids=""

# Loop through each match
while read -r match; do
    # Look for the end of the match so the contents can be searched
    match_end=$(echo "$v4l2_output" | grep -n "$match" | awk -F: '{print $1}' | tail -n1)
    devices=$(echo "$v4l2_output" | sed -n "/$match/,/$match_end/ p" | grep -E '(/\dev/media[0-9]+|\dev/video[0-9]+)')

    # Check if match found
    if [ -n "$devices" ]; then
        # Find the ID from the match
        id=$(echo "$match" | grep -oE '\([0-9a-fA-F:]+\)' | tr -d '()')
        ids="${ids} ${id}"
    fi
done <<< "$matches"

ids=$(echo "$ids" | tr -d ' ')

# highlight /dev/video* and /dev/media* in yellow
v4l2_output=$(echo "$v4l2_output" | sed -E 's#/dev/(media[^[:space:]]*|video[^[:space:]]*)#\o033[43;30m&\o033[0m#g')

# highlight the device IDs in pink
v4l2_output=$(echo "$v4l2_output" | sed -E "s@($ids)@\o033[45;30m&\o033[0m@g")

lsusb_output=$(lsusb)


bus_ids=$(echo "$lsusb_output" | sed -En "s/Bus ([0-9]{3}) Device ([0-9]{3}): ID ($ids).*/\1/p" | awk '{ printf "%d", $1 }')
bus_addrs=$(echo "$lsusb_output" | sed -En "s/Bus ([0-9]{3}) Device ([0-9]{3}): ID ($ids).*/\2/p" | awk '{ printf "%d", $1 }')

lsusb_output=$(echo "$lsusb_output" | sed -E "s/Bus ([0-9]{3}) Device ([0-9]{3}): ID ($ids)/Bus \x1b[46;30m\1\x1b[0m Device \x1b[42;30m\2\x1b[0m: ID \3/g")
lsusb_output=$(echo "$lsusb_output" | sed -E "s@($ids)@\o033[45;30m&\o033[0m@g")



if [ "$target" = "usb" ]; then
    echo ==============================================================
    echo -e "$v4l2_output"
    echo ==============================================================
    echo -e "$lsusb_output"
    echo ==============================================================

    # Print the matches
    echo "$matches"

    # Print the extracted IDs
    echo "Extracted Device IDs:    ${ids}"
    echo "Extracted USB Bus IDs:   ${bus_ids}"
    echo "Extracted USB Addresses: ${bus_addrs}"

    echo ==============================================================
fi

if [ "$target" = "build" ] || [ "$target" = "bar" ]; then
    docker build -t doorbellian:dev .
fi

if [ "$target" = "run" ] || [ "$target" = "bar" ] || [ "$target" = "bash" ]; then

    if [ ! -e "/dev/media0" ] || [ ! -e "/dev/video0" ]; then
        echo could not find /dev/media0 or /dev/video0
        exit 3
    fi

    if [ "$target" = "bash" ]; then
        container_cmd="/bin/bash"
    else
        container_args="$bus_ids $bus_addrs"
    fi

    docker run -it --rm \
	--privileged \
	\
        --device=/dev/bus/usb:/dev/bus/usb \
        --device=/dev/media0 \
        --device=/dev/video0 \
        --device=/dev/video1 \
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


