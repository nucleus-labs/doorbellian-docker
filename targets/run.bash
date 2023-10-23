

description="run docker container with default command"

function target_run () {
    usb_init
    validate_usb_devices
    local _target="run_container"
    local container_ids=($(docker ps -a --filter "ancestor=doorbellian:${image_tag}" --format '{{.ID}}' 2>/dev/null))
    [[ ${attach} -ne 0 && ${#container_ids} -eq 1 ]] && _target="exec_container"
    eval "${_target} \"./doorbellian-qemu.sh\" ${usb_list[@]}"
}
