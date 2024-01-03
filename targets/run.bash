

description="run docker container with default command"

ENTRYPOINT='"./doorbellian-qemu.sh" ${usb_list[@]}'

add_flag '-' "override" "runs the provided override instead of default entrypoint" 1 "docker args" "string" "the override"
function flag_name_override () {
    local override="$1"
    ENTRYPOINT="${override}"
}

function target_run () {
    local docker_args=($@)
    usb_init
    validate_usb_devices
    local _target="run_container"
    local container_ids=($(docker ps -a --filter "ancestor=doorbellian:${image_tag}" --format '{{.ID}}' 2>/dev/null))
    [[ ${attach} -ne 0 && ${#container_ids} -eq 1 ]] && _target="exec_container"
    eval "${_target} ${ENTRYPOINT}"
}
