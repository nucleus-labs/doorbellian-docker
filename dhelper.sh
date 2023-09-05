#!/usr/bin/env bash
# set -x

source arg_parse.sh

# ================================================================================================
#                                            SETTINGS
dockerfile="Dockerfile.default"
container_id=
attach=0
persist=0

# ================================================================================================
#                                            GLOBALS
DEPENDENCIES=("cam" "lsusb")

IFS_DEFAULT=$IFS
arguments=($*)

force=n

# ================================================================================================
#                                              UTILS
# (1: array name (global); 2: array type (-a/-A))
function arr_max_length () {
    [[ -z "$1" ]]           && caller && echo "[ERROR]: Array name is empty!"                       && exit 70
    local arr_declare="$(declare -p "$1" 2>/dev/null)"
    [[ -z "${!1+x}" || "${arr_declare}" != "declare"* ]]                                            \
                            && caller && echo "[ERROR]: Variable '$1' does not exist!"              && exit 81
    [[ ! -v "$1"    || "${arr_declare}" != "declare -a"* && "${arr_declare}" != "declare -A"* ]]    \
                            && caller && echo "[ERROR]: Variable '$1' is not an array!"             && exit 82
    [[ ! -z "$3" && "$3" != "-a" && "$3" != "-A" ]]                                                 \
                            && caller && echo "[ERROR]: Array type '$3' is not a valid type!"       && exit 83
    local -n arr="$1"
    local max_length=${arr[0]}

    for item in "${arr[@]}"; do
        max_length=$(( ${#item} > ${max_length} ? ${#item} : ${max_length} ))
    done
    echo ${max_length}
}

# (1: array name (global); 2: array type (-a/-A))
function arr_max_value () {
    [[ -z "$1" ]]           && caller && echo "[ERROR]: Array name is empty!"                       && exit 80
    local arr_declare="$(declare -p "$1" 2>/dev/null)"
    [[ -z "${!1+x}" || "${arr_declare}" != "declare"* ]]                                            \
                            && caller && echo "[ERROR]: Variable '$1' does not exist!"              && exit 81
    [[ ! -v "$1"    || "${arr_declare}" != "declare -a"* && "${arr_declare}" != "declare -A"* ]]    \
                            && caller && echo "[ERROR]: Variable '$1' is not an array!"             && exit 82
    [[ ! -z "$3" && "$3" != "-a" && "$3" != "-A" ]]                                                 \
                            && caller && echo "[ERROR]: Array type '$3' is not a valid type!"       && exit 83
    local -n arr="$1"
    local max_value=${arr[0]}

    for item in "${arr[@]}"; do
        [[ ! $2 =~ ^[0-9]+$ ]]  && caller && echo "[ERROR]: value '$2' is not a valid number!"      && exit 84
        max_value=$(( ${item} > ${max_value} ? ${item} : ${max_value} ))
    done
    echo ${max_value}
}

# (1: array name (global); 2: index to pop; 3: array type (-a/-A))
function arr_pop () {
    [[ -z "$1" ]]           && caller && echo "[ERROR]: Array name is empty!"                       && exit 90
    local arr_declare="$(declare -p "$1" 2>/dev/null)"
    [[ -z "${!1+x}" || "${arr_declare}" != "declare"* ]]                                            \
                            && caller && echo "[ERROR]: Variable '$1' does not exist!"              && exit 81
    [[ ! -v "$1"    || "${arr_declare}" != "declare -a"* && "${arr_declare}" != "declare -A"* ]]    \
                            && caller && echo "[ERROR]: Variable '$1' is not an array!"             && exit 82
    [[ ! $2 =~ ^[0-9]+$ ]]  && caller && echo "[ERROR]: Index '$2' is not a valid number!"          && exit 93
    [[ ! -v $1[$2] ]]       && caller && echo "[ERROR]: Array element at index $2 does not exist!"  && exit 94
    [[ ! -z "$3" && "$3" != "-a" && "$3" != "-A" ]]                                                 \
                            && caller && echo "[ERROR]: Array type '$3' is not a valid type!"       && exit 95
    eval "$1=(\${$1[@]:0:$2} \${$1[@]:$2+1})"
}


# ================================================================================================
#                                             TASKS
function init () {
    return
}

function validate_dependencies () {
    return
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

    # Split variables into arrays based on comma (,)
    IFS=',' read -ra a_array <<< "$bus_ids"
    IFS=',' read -ra b_array <<< "$bus_addrs"

    usb_list=()
    for ((i=0; i<${#a_array[@]}; i++)); do
        # Find the ID from the match
        local addition=(${a_array[$i]},${b_array[$i]})
        usb_list+=(${addition})
    done
}

# (1: container command; 2: container command arguments)
function run_container () {
    local container_cmd=$1
    shift
    local container_args="$*"
    
    local device_args=""
    for dev in $(ls /dev/{video,media}* 2>/dev/null); do
        device_args="$device_args --device=$dev"
    done

    if [ -z "$device_args" ] && [ "$force" = "n" ]; then
        echo "No video devices found. Run with -f to force run"
        exit 3
    fi

    __rm="--rm"
    [[ $persist -ne 0 ]] && __rm=""

    docker run -it ${__rm} \
        --privileged \
        \
        --device=/dev/bus/usb:/dev/bus/usb  \
        ${device_args}                      \
        \
        -p 1935:1935                        \
        -p 8000:8000                        \
        -p 8001:8001                        \
        -p 8554:8554                        \
        -p 8888:8888                        \
        -p 8889:8889                        \
        \
        doorbellian:dev ${container_cmd} ${container_args}
}

# (1: container command; 2: container command arguments)
function exec_container () {
    local container_cmd=$1
    local container_args=$2
    local container_id="$(docker ps -a --filter 'ancestor=doorbellian:dev' --format '{{.ID}}')"

    [[ ! $container_id ]] && caller && echo "[ERROR]: Could not find an existing container..." && exit 10

    docker start ${container_id} >/dev/null
    docker exec -it ${container_id} ${container_cmd} ${container_args}
}

# ================================================================================================
#                                              FLAGS
add_flag "f" "force" "run even if no camera devices are found" 1
function flag_f () {
    echo forcing...
    force=y
}

add_flag "p" "persistent" "container should persist after use" 1
function flag_p () {
    persist=1
    echo "Container will persist after use."
}

add_flag "a" "attach" "attach to existing persistent container if one exists" 2
function flag_a () {
    attach=1
    echo "Attaching to container..."
}

add_flag "u" "update" "updates a container by copying the contents of 'deps/' into a currently running container before executing the target ; implicitly uses the -a flag" 2
function flag_u () {
    flag_a
    local container_ids=
    return
}

add_flag "-" "dockerfile" "sets the dockerfile to use" 1 "dockerfile" ""
function flag_name_dockerfile () {
    dockerfile="${arguments[0]}"
    arr_pop arguments 0
    echo "using dockerfile '${dockerfile}'"
}

add_flag "-" "container" "the id for the container that should be used" 1 "container_id" ""
function flag_name_container () {
    container_id="${arguments[0]}"
    return
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
        local extracts=("build.log" ${arguments[@]})
        local container_id=($(docker ps -a --filter 'ancestor=doorbellian:dev' --format '{{.ID}}' 2>/dev/null))
        local created=0
        IFS=','
        [[ ${#container_id[@]} -gt 1 ]] && caller && echo "[ERROR]: too many available containers: (${container_id[*]})" && exit 20
        IFS=$IFS_DEFAULT
        [[ ${#container_id[@]} -eq 0 ]] && created=1 && container_id=($(docker create doorbellian:dev))
        for extract in "${extracts[@]}"; do
            echo "Extracted '${container_id:0:8}:${extract}' to 'tmp/${extract}'"
            docker cp "${container_id}:/builds/linux/${extract}" "tmp/${extract}" 2>&1 >/dev/null
        done
        (( ${created} == 1 )) && docker rm -v ${container_id} 2>&1 >/dev/null
    fi
}

add_target "bae" "build target followed by extract target"
function target_bae () {
    target_build
    target_extract
}

add_target "run" "run docker container with default command"
function target_run () {
    usb_init
    local _target="run_container"
    local container_ids=($(docker ps -a --filter 'ancestor=doorbellian:dev' --format '{{.ID}}' 2>/dev/null))
    [[ ${attach} -ne 0 && ${#container_ids} -eq 1 ]] && _target="exec_container"
    eval "${_target} \"./doorbellian-qemu.sh\" ${usb_list[@]}"
}

add_target "bash" "run docker container with /bin/bash"
function target_bash () {
    local _target="run_container"
    local container_ids=($(docker ps -a --filter 'ancestor=doorbellian:dev' --format '{{.ID}}' 2>/dev/null))
    [[ ${attach} -ne 0 && ${#container_ids} -eq 1 ]] && _target="exec_container"
    eval "${_target} '/bin/bash'"
}

add_target "kill" "kills and deletes related running containers"
function target_kill () {
    local container_ids=($(docker ps -a --filter 'ancestor=doorbellian:dev' --format '{{.ID}}' 2>/dev/null))
    [[ ${#container_ids[@]} -eq 0 ]] && echo "No containers to kill." && return

    for container_id in "${container_ids[@]}"; do
        docker kill "$container_id" 2>&1 >/dev/null
        [[ $? -eq 0 ]] && echo "Container $container_id killed."

        docker rm "$container_id"
        [[ $? -eq 0 ]] && echo "Container $container_id deleted."
    done
}

add_target "bar" "build target followed by run target"
function target_bar () {
    target_build
    target_run
}

add_target "debug" "use buildg to step through the dockerfile"
function target_debug () {
    buildg debug --file ${dockerfile} .
    exit 0
}

# ================================================================================================
#                                               MAIN
function main () {
    validate_dependencies
    init
    validate_flags
    execute_flags
    validate_target
}

main

