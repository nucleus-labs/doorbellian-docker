

description="kills and deletes containers with the provided tag"

function target_kill () {
    local container_ids=($(docker ps -a --filter "ancestor=doorbellian:${image_tag}" --format '{{.ID}}' 2>/dev/null))
    [[ ${#container_ids[@]} -eq 0 ]] && echo "No containers to kill." && return

    for container_id in "${container_ids[@]}"; do
        docker kill "${container_id}" 2>&1 >/dev/null
        [[ $? -eq 0 ]] && echo "Container ${container_id} killed."

        docker rm "${container_id}" 2>&1 >/dev/null
        [[ $? -eq 0 ]] && echo "Container ${container_id} deleted."
    done
}
