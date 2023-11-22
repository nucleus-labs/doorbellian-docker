
description="run docker container with /bin/bash"

function target_bash () {
    local _target="run_container"
    local container_ids=($(docker ps -a --filter "ancestor=doorbellian:${image_tag}" --format '{{.ID}}' 2>/dev/null))
    [[ ${attach} -ne 0 && ${#container_ids} -eq 1 ]] && _target="exec_container"
    eval "${_target} '/bin/bash'"
}
