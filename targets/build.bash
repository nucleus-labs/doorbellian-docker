
description="build the docker image"


add_flag "-" "stage" "docker build stage to build" 1 "build stage" "string" "the stage to build"
function flag_name_stage () {
    extra_args+=("--target $1")
}

JOBS=1
add_flag "-" "jobs" "sets the number of jobs/threads to use" 1 "job count" "int" "the number of jobs/threads to use"
function flag_name_jobs () {
    [[ ! ${JOBS} =~ ^[0-9]+$ ]] && caller && echo "[ERROR]: JOBS value '${JOBS}' is not a valid number!" && exit 15
    JOBS=$1
    debug "Using -j${JOBS}"
}

add_flag "-" "no-cache" "specified '--no-cache' to docker for image build" 2
function flag_name_no_cache () {
    extra_args+=("--no-cache")
}


function target_build () {
    # labels are for detection later, intended to be used in cleanup functions,
    # which don't have tag-based filters, but do have label-based filters
    local _run="docker build --label purpose=\"doorbellian\" --label _tag=\"${image_tag}\" --build-arg JOBS=${JOBS} -f \"${dockerfile}\" -t doorbellian:${image_tag} ${extra_args[*]} ."
    debug "${_run}"
    eval "${_run}"
    return $?
}

