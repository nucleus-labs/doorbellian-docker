#!/usr/bin/env bash
# set -x

# ================================================================================================
#                                            SETTINGS
dockerfile="Dockerfile.tina"

# ================================================================================================
#                                            GLOBALS
IFS_DEFAULT=$IFS
arguments=($*)
valid_flags=()
valid_flag_names=()
valid_flag_descriptions=()
valid_targets=()
valid_target_descriptions=()
force=n

# ================================================================================================
#                                              UTILS

# (1: array name (global))
function arr_max_length () {
    [[ -z "$1" ]]           && echo "Error: Array name is empty!"                       && exit 80
    [[ -z "${!1+x}" ]]      && echo "Error: Variable '$1' does not exist!"              && exit 81
    [[ ! -v "$1" || "$(declare -p "$1" 2>/dev/null)" != "declare -a"* ]] \
                            && echo "Error: Variable '$1' is not an array!"             && exit 82
    eval "local arr=(\"\${$1[@]}\")"
    local max_length=${arr[0]}

    for item in "${arr[@]}"; do
        max_length=$(( ${#item} > max_length ? ${#item} : $max_length ))
    done
    echo ${max_length}
}

# (1: array name (global); 2: index to pop)
function arr_pop () {
    [[ -z "$1" ]]           && echo "Error: Array name is empty!"                       && exit 90
    [[ -z "${!1+x}" ]]      && echo "Error: Variable '$1' does not exist!"              && exit 91
    [[ ! -v "$1" || "$(declare -p "$1" 2>/dev/null)" != "declare -a"* ]] \
                            && echo "Error: Variable '$1' is not an array!"             && exit 92
    [[ ! $2 =~ ^[0-9]+$ ]]  && echo "Error: Index is not a valid number!"               && exit 93
    [[ ! -v $1[$2] ]]       && echo "Error: Array element at index $2 does not exist!"  && exit 94
    eval "$1=(\${$1[@]:0:$2} \${$1[@]:$2+1})"
}

# ================================================================================================
#                                             TASKS
# (1: flag (single character); 2: flag name; 3: flag description)
function add_flag () {
    [[ ${#1} -eq 0 ]]   && echo "Error: Flags cannot be empty!"                                     && exit 60
    [[ ${#1} -ne 1 ]]   && echo "Error: Flag '${1}' is invalid! Flags must be a single character!"  && exit 61
    valid_flags+=("$1")
    valid_flag_names+=("$2")
    valid_flag_descriptions+=("$3")
}

# (1: target name; 2: target description)
function add_target () {
    [[ ${#1} -eq 0 ]]   && echo "Error: Targets cannot be empty!"                                   && exit 70
    valid_targets+=("$1")
    valid_target_descriptions+=("$2")
}

function d_help () {
    local usage_flags=""
    local usage_targets=""

    local formatted_description=""
    local formatted_description_linecount=0

    # (1: description; 2: left-padding, 3: line-width)
    function format_description () {
        [[ -z "$1" ]]           && echo "Error: description is empty!"                  && exit 30
        [[ ! $2 =~ ^[0-9]+$ ]]  && echo "Error: left-padding is not a valid number!"    && exit 31
        [[ ! $3 =~ ^[0-9]+$ ]]  && echo "Error: line width is not a valid number!"      && exit 32

        formatted_description=""
        formatted_description_linecount=1
        local description="$1"
        local left_padding=$( printf "%${2}s" )
        local line_width=$3

        local current_line=""

        IFS=" "
        read -ra words <<< "$description"
        IFS=$IFS_DEFAULT

        local used_left_padding="$left_padding"

        for word in "${words[@]}"; do
            if (( ${#used_left_padding} + ${#current_line} + ${#word} + 1 > $line_width )); then
                (( ${formatted_description_linecount} == 1 )) && used_left_padding=""
                formatted_description="${formatted_description}${used_left_padding}${current_line}\n"
                current_line="${word}"
                formatted_description_linecount=$(($formatted_description_linecount+1))
                used_left_padding="$left_padding"
            else
                if [ -z "$current_line" ]; then # true for i=0
                    current_line="$word"
                else
                    current_line="$current_line $word"
                fi
            fi
        done

        (( ${formatted_description_linecount} == 1 )) && used_left_padding=""
        formatted_description="${formatted_description}${used_left_padding}${current_line}\n"
    }

    local max_flag_width=$(   arr_max_length valid_flag_names )
    local max_target_width=$( arr_max_length valid_targets    )

    # set to max
    max_flag_width=$((   $max_flag_width   > 19 ? $max_flag_width   : 19 ))
    max_target_width=$(( $max_target_width > 19 ? $max_target_width : 19 ))

    local max_width=$(($max_flag_width > $max_target_width ? $max_flag_width : $max_target_width ))

    for ((i = 0; i < ${#valid_flags[@]}; i++)); do
        local flag="${valid_flags[i]}"
        local flag_name="${valid_flag_names[i]}"

        local flag_padding=$((${#flag_name} <= $max_width ? $max_width - ${#flag_name} + 1 : 1))
        local flag_spaces=$(printf "%${flag_padding}s")

        local line="    -${flag}   | ${flag_name}${flag_spaces}| "

        format_description "${valid_flag_descriptions[i]}" ${#line} 80

        usage_flags="${usage_flags}${line}${formatted_description}\n"
    done

    format_description=""

    for ((i = 0; i < ${#valid_targets[@]}; i++)); do
        local target="${valid_targets[i]}"

        local target_padding=$((${#target} <= $max_width ? $max_width - ${#target} + 8 : 1))
        local target_spaces=$(printf "%${target_padding}s" " ")

        local line="    ${target}${target_spaces}| "

        format_description "${valid_target_descriptions[i]}" ${#line} 80
        
        usage_targets="${usage_targets}${line}${formatted_description}\n"
    done

    echo "Usage: $0 [flags, ...] <target> [target_arguments...]"
    echo ""
    echo "A helpful tool for doorbellian development"
    echo ""
    echo "Maintained by Maxine Alexander <max.alexander3721@gmail.com>"
    echo ""
    echo "--------------------------------------------------------------------------------------"
    echo ""
    local target_spaces=$(printf "%$(($max_width - 3))s" " ")
    echo "    flag | name${target_spaces}| description"
    echo "    ------------------------------------------------------------------------------"
    echo -e "$usage_flags"
    echo "--------------------------------------------------------------------------------------"
    target_spaces=$(printf "%$(($max_width + 2))s" " ")
    echo "    target${target_spaces}| description"
    echo "    ------------------------------------------------------------------------------"
    echo -e "$usage_targets"
    echo ""
}

function usb_init () {
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
}

# (1: container command; 2: container command arguments)
function run_container () {
    usb_init

    container_cmd=$1
    container_args=$2

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
}

# (1: flag (single character))
function validate_flag () {
    # return

    flag=$1
    valid_flag_found=0

    # check if the supplied flag is valid
    for value in "${valid_flags[@]}"; do
        if [ "$flag" = "$value" ]; then
            valid_flag_found=1
            break
        fi
    done

    # if no valid flag matching the supplied flag is found, error
    if [ $valid_flag_found -eq 0 ]; then
        echo "Error: '-$flag' is not a valid flag."
        d_help
        exit 1
    else
        eval "flag_${flag}"
    fi
}

function validate_flags () {
    arg=${arguments[0]}

    if [ "${arg:0:1}" != "-" ]; then
        return
    fi
    
    arr_pop arguments 0

    flags=$arg
    for (( i=1; i<${#flags}; i++ )); do
        validate_flag ${flags:$i:$i+1}
    done

    validate_flags
}

function validate_target () {
    target=${arguments[0]}
    valid_target_found=0

    unset -v ${arguments[0]}

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
        d_help
        exit 2
    else
        eval "target_${target}"
    fi
}

# ================================================================================================
#                                              FLAGS
add_flag "h" "help" "prints this menu"
function flag_h () {
    d_help
    exit 0
}

add_flag "f" "force" "run even if no camera devices are found"
function flag_f () {
    echo forcing...
    force=y
}

# ================================================================================================
#                                             TARGETS
add_target "usb" "list found camera devices"
function target_usb () {
    usb_init

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
}

add_target "clean" "clean out the related containers and images, and dangling images"
function target_clean () {
    echo cleaning...
    docker ps -a --filter "status=created" --format "{{.ID}}" | xargs -r docker rm
    docker ps -a --filter "status=exited" --format "{{.ID}}" | xargs -r docker rm
    if [ -n "$(docker images -q doorbellian:dev 2> /dev/null)" ]; then
        docker image rm --force doorbellian:dev
    fi
    docker images -f "dangling=true" --format "{{.ID}}" | xargs -r docker rmi
    echo cleaned.
}

add_target "build" "build the docker image"
function target_build () {
    export DOCKER_BUILDKIT=0
    # --rm=false
    docker build --progress=plain -f "${dockerfile}" \
        -t doorbellian:dev .
}

add_target "extract" "extract logs from the constructed image"
function target_extract () {
    if [ -n "$(docker images -q doorbellian:dev 2> /dev/null)" ]; then
        LOG_ID=$(docker create doorbellian:dev)
        docker cp $LOG_ID:/builds/linux-tina/build.tina ./build.tina
        docker rm -v $LOG_ID
    fi
    echo Extracted.
}

add_target "bae" "build target followed by extract target"
function target_bae () {
    target_build
    target_extract
}

add_target "run" "run docker container with default command"
function target_run () {
    run_container "./doorbellian-qemu.sh" "${usb_list[@]}"
}

add_target "bash" "run docker container with /bin/bash"
function target_bash () {
    run_container "/bin/bash" $*
}

add_target "bar" "build target followed by run target"
function target_bar () {
    target_build
    target_run
}

# ================================================================================================
#                                               MAIN
function main () {
    # TODO: validate dependencies
    validate_flags
    validate_target
}

main

