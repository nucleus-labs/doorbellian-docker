
description="build the docker image"

function target_build () {
    local _run="docker build --label purpose=\"doorbellian\" --label _tag=\"${image_tag}\" --build-arg JOBS=${JOBS} -f \"${dockerfile}\" -t doorbellian:${image_tag} ${extra_args[*]} ."
    debug "${_run}"
    eval "${_run}"
    return $?
}

