#!/usr/bin/env bash
# set -x

# ================================================================================================

dockerfile="Dockerfile.tina"
valid_flags=("h" "f")
valid_targets=("usb" "build" "clean" "bash" "run" "bar" "debug")
valid_target_found=0
container_cmd=./doorbellian-qemu.sh
force=n

function help () {
    echo "Usage: $0 [flag, ...] <target>"
    echo ""
    echo "A helpful tool for doorbellian development"
    echo ""
    echo "Maintained by Maxine Alexander <max.alexander3721@gmail.com>"
    echo ""
    echo "--------------------------------------------------------------------------------------"
    echo ""
    echo "    flag        | name        | description"
    echo ""
    echo "    -h          | help        | prints this menu"
    echo "    -f          | force       | run even if no camera devices are found"
    echo ""
    echo "--------------------------------------------------------------------------------------"
    echo ""
    echo "    target                    | description"
    echo ""
    echo "    usb                       | list found camera devices"
    echo "    build                     | build the docker container"
    echo "    clean                     | clean out the related containers and images, and"
    echo "                                dangling images"
    echo "    run                       | run the container with the default command:"
    echo "                                \"$container_cmd\""
    echo "    bash                      | run the container with the \"/bin/bash\" command"
    echo "    bar                       | build target then run target"
    echo "    debug                     | launches "
    echo ""
}


if [ "$1" = "--help" ] || [ "$1" == "-h" ]; then
    help
    exit 0
fi

if [ "$1" = "-f" ]; then
    force=y
    shift
fi

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
    help
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
    usb_list=(${usb_list} ${a_array[$i]},${b_array[$i]})
done


if [ "$target" = "usb" ]; then
    echo ==============================================================
    echo -e "$cam_output"
    echo ==============================================================
    echo -e "$lsusb_output"
    echo ==============================================================

    # Print the extracted IDs
    echo "Extracted Device IDs:    ${ids//|/,}"
    echo "Extracted USB Bus IDs:   ${bus_ids}"
    echo "Extracted USB Addresses: ${bus_addrs}"
    echo "Extracted USB List:      ${usb_list[@]}"

    echo ==============================================================
fi

if [ "$target" = "clean" ]; then
    docker ps -a --filter "status=created" --format "{{.ID}}" | xargs -r docker rm
    docker ps -a --filter "status=exited" --format "{{.ID}}" | xargs -r docker rm
    if [ -n "$(docker images -q doorbellian:dev 2> /dev/null)" ]; then
        docker image rm --force doorbellian:dev
    fi
    docker images -f "dangling=true" --format "{{.ID}}" | xargs -r docker rmi
fi

if [ "$target" = "build" ] || [ "$target" = "bar" ]; then
    export DOCKER_BUILDKIT=0
    # --rm=false
    docker build --progress=plain -f "${dockerfile}" \
        -t doorbellian:dev .
    BUILD_RESULT=$?
    
    if [ $BUILD_RESULT -eq 0 ]; then
        LOG_ID=$(docker create doorbellian:dev)
        docker cp $LOG_ID:/builds/linux-tina/build.tina ./build.tina
        docker rm -v $LOG_ID
    fi
    # TODO: output build log to "build.tina"
fi

if [ "$target" = "run" ] || [ "$target" = "bar" ] || [ "$target" = "bash" ]; then

    if [[ "$target" = "bash" ]]; then
        container_cmd="/bin/bash"
    else
        container_args="${usb_list[@]}"
    fi

    device_args=""
    for dev in $(ls /dev/{video,media}* 2>/dev/null); do
        device_args="$device_args --device=$dev"
    done

    if [ -z "$device_args" ] && [ "$force" = "n" ]; then
        echo "No video devices found. Run with -f to force run"
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


