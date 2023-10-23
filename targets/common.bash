

# ================================================================================================
#                                            SETTINGS
debug_mode=0
dockerfile="modes/Dockerfile.default"
JOBS=$(nproc --all)
container_id=
force=0
attach=0
persist=0
auto_select=0
image_tag="dev"
extra_args=()


# ================================================================================================
#                                            GLOBALS
DEPENDENCIES=()

SCRIPT_NAME=$0

created_container=
selected_item_index=
IFS_DEFAULT=${IFS}

# ================================================================================================
#                                             TASKS
# (1: message to print)
function debug () {
    [[ ${debug_mode} -eq 1 ]] && echo $1
}

function get_container_id () {
    local container_ids=($(docker ps -a --filter "ancestor=doorbellian:${image_tag}" --format '{{.ID}}' 2>/dev/null))

    [[ ${#container_ids[@]} -ge 1 ]] && container_id="${container_ids[0]}"

    [[ x"${container_id}" == x"" ]] && {
        [[ ${created_container} -eq 1 ]] && {
            echo "Houston, we have a problem" >&2 # should be impossible ; sanity check
            exit 255
        }
        created_container=1
        container_id="$(docker create doorbellian:${image_tag})"
    }
    echo "${container_id}"
}

# sets variables `cam_output`, `ids`, `lsusb_output`, `bus_ids`, `bus_addrs`, `usb_list` for use elsewhere
function usb_init () {
    # Store video devices using libcamera
    cam_output=$(cam -l 2>/dev/null)

    # Find device entries like "UVC Camera (046d:0825) (usb-0000:00:14.0-3)"
    ids=$(echo "${cam_output}" | grep -oE '[0-9a-f]{4}:[0-9a-f]{4}' | uniq)
    ids=$(echo -n "${ids}" | tr "\n" "|")

    # highlight the device IDs in pink
    cam_output=$(echo "${cam_output}" | sed -E "s@(${ids})@\o033[45;30m&\o033[0m@g")

    # Store usb devices using usbutils
    lsusb_output=$(lsusb)

    bus_ids=$(echo "${lsusb_output}" | sed -En "s/Bus ([0-9]{3}) Device ([0-9]{3}): ID (${ids}).*/\1/p" | awk '{ printf "%d,", $1 }' | head -c -1)
    bus_addrs=$(echo "${lsusb_output}" | sed -En "s/Bus ([0-9]{3}) Device ([0-9]{3}): ID (${ids}).*/\2/p" | awk '{ printf "%d,", $1 }' | head -c -1)

    lsusb_output=$(echo "${lsusb_output}" | sed -E "s/Bus ([0-9]{3}) Device ([0-9]{3}): ID (${ids})/Bus \x1b[46;30m\1\x1b[0m Device \x1b[42;30m\2\x1b[0m: ID \3/g")

    # Split variables into arrays based on comma (,)
    IFS=',' read -ra id_list <<< "${bus_ids}"
    IFS=',' read -ra addr_list <<< "${bus_addrs}"

    usb_list=()
    for ((i=0; i<${#id_list[@]}; i++)); do
        # Find the ID from the match
        local addition=(${id_list[$i]},${addr_list[$i]})
        usb_list+=(${addition})
    done
}

function validate_usb_devices () {
    for ((i=0; i<${#id_list[@]}; i++)); do
        local id=$(printf "%0.3i" ${id_list[$i]})
        local addr=$(printf "%0.3i" ${addr_list[$i]})
        local device="/dev/bus/usb/${id}/${addr}"

        # TODO: Check why this works on some systems and not others
        # Check permissions for the device
        if [[ ! -w "${device}" && ${force} -eq 0 ]]; then
            error ${BASH_SOURCE[0]} ${LINENO} "Device '${device}' is not writable by the current user, please chown the device" 120
        elif [[ ! -w "${device}" && ${force} -eq 1 ]]; then
            echo "Device '${device}' is not writable by the current user, please chown the device. Forcing..."
        fi
    done
}

# (1: default for auto-select; *: list items)
function select_index_from_list () {
    local default_choice=0
    [[ ! -z $1 || $1 -eq -1 ]] && default_choice=$1
    [[ ! $1 =~ ^[0-9]+$ ]] \
            && error ${BASH_SOURCE[0]} ${LINENO} "Default index is invalid!"                90
    [[ ${auto_select} -eq 1 ]] \
            && echo "Selecting [${list[0]}]" && return ${default_choice}
    shift
    local list=($*)
    echo "$(declare -p "list" 2>/dev/null)"
    eval "$(declare -p "list" 2>/dev/null)"
    [[ ${#list} -eq 0 ]] \
            && error ${BASH_SOURCE[0]} ${LINENO} "No values provided!"                      91
    IFS=',' echo "items: (${list[@]})"
    for ((i = 0; i <= ${#list}; i++)); do
        local item="${list[i]}"
        printf "%0.2i: ${item}\n" $i
    done

    read -p "Choice? " selected_index

    [[ ! ${selected_index} =~ ^[0-9]+$ ]] \
            && error ${BASH_SOURCE[0]} ${LINENO} "Selected choice is not a valid number"    92
    [[ ${selected_index} -lt 0 || ${selected_index} -gt ${#list} ]] \
            && error ${BASH_SOURCE[0]} ${LINENO} "Selected choice is not a valid index"     93
    selected_item_index=${selected_index}
}

# (1: container command; 2: container command arguments)
function run_container () {
    local container_cmd=$1
    shift
    local container_args="$*"
    
    local device_args=""
    for dev in $(ls /dev/{video,media}* 2>/dev/null); do
        device_args="${device_args} --device=${dev}"
    done

    if [[ -z "${device_args}" && ${force} -eq 0 ]]; then
        echo "No video devices found. Run with -f to force run"
        exit 3
    fi

    __rm="--rm"
    [[ ${persist} -ne 0 ]] && __rm=""

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
        doorbellian:${image_tag} ${container_cmd} ${container_args}
}

# (1: container command; 2: container command arguments)
function exec_container () {
    local container_cmd=$1
    local container_args=$2
    local container_id="$(docker ps -a --filter \"ancestor=doorbellian:${image_tag}\" --format '{{.ID}}')"

    [[ ! ${container_id} ]] && caller && echo "[ERROR]: Could not find an existing container..." && exit 10

    docker start ${container_id} >/dev/null
    docker exec -it ${container_id} ${container_cmd} ${container_args}
}

# ================================================================================================
#                                              FLAGS
add_flag "d" "debug" "enable debug mode (prints extra info)" 0
function flag_name_debug () {
    debug_mode=1
    caller
    debug "Enabling Debug Mode"
}

add_flag "f" "force" "run even if no camera devices are found" 1
function flag_name_force () {
    debug "forcing..."
    force=1
}

add_flag "p" "persistent" "container should persist after use" 1
function flag_name_persistent () {
    persist=1
    debug "Container will persist after use."
}

add_flag "a" "attach" "attach to existing persistent container if one exists" 2
function flag_name_attach () {
    attach=1
    if [[ -z "${container_id}" ]]; then
        local container_ids=($(docker ps -a --filter "ancestor=doorbellian:${image_tag}" --format '{{.ID}}' 2>/dev/null))
        if [[ ${#container_ids} -eq 0 ]]; then
            created_container=1
            debug "Creating container..."
            container_id="$(docker ps -a --filter "ancestor=doorbellian:${image_tag}" --format '{{.ID}}' 2>/dev/null)"
        elif [[ ${#container_ids} -eq 1 ]]; then
            container_id="$container_ids"
        else
            select_index_from_list 0 ${container_ids[@]}
            container_id="${container_ids[selected_item_index]}"
        fi
    fi
    debug "Attaching to container [${container_id:0:8}]..."
}

add_flag "-" "tag" "sets the docker tag for the selected target" 2
function flag_name_tag () {
    image_tag="${arguments[0]}"
    debug "using tag '${image_tag}'"
    arr_pop arguments 0
}

add_flag "-" "jobs" "sets the number of jobs/threads to use" 1
function flag_name_jobs () {
    [[ ! ${JOBS} =~ ^[0-9]+$ ]] && caller && echo "[ERROR]: JOBS value '${JOBS}' is not a valid number!" && exit 15
    JOBS=${arguments[0]}
    arr_pop arguments 0
    debug "Using -j${JOBS}"
}

add_flag "-" "dockerfile" "sets the dockerfile to use" 2 "dockerfile" "string" "the dockerfile to use"
function flag_name_dockerfile () {
    dockerfile="modes/${arguments[0]}"
    arr_pop arguments 0
    debug "using dockerfile '${dockerfile}'"
}

add_flag "-" "container" "the id for the container that should be used" 1 "container_id" "string" "the id of the docker container that should be used"
function flag_name_container () {
    container_id="${arguments[0]}"
    debug "Using container [${container_id}]"
}

add_flag "-" "mode" "sets the project mode, runs \"source modes/\${mode}.bash\"" 1
function flag_name_mode () {
    local mode="modes/${arguments[0]}.bash"
    [[ ! -f "${mode}" ]] && {
        echo "Could not find mode file '${mode}'" >&2
        exit 255
    }

    source ${mode}
    arr_pop arguments 0
    debug "using dockerfile:    '${dockerfile}'"
    debug "using tag:           '${image_tag}'"
}

add_flag "-" "arg" "additional arguments to pass to the target, can be used multiple times" 1
function flag_name_arg () {
    extra_args+=(${arguments[0]})
    arr_pop arguments 0
}

add_flag "-" "no-cache" "Only functions during the build target, builds a docker image without using a cache" 2
function flag_name_no_cache () {
    extra_args+=("--no-cache")
}

add_flag "-" "stage" "docker build stage to build" 1
function flag_name_stage () {
    extra_args+=("--target ${arguments[0]}")
    arr_pop arguments 0
}

