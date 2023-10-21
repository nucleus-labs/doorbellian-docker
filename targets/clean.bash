

description="clean out the related containers and images, and dangling images"

function target_clean () {
    debug "stopping containers..."
    docker ps -a --filter "status=running" --filter "ancestor=doorbellian:${image_tag}" --format "{{.ID}}" | xargs -r docker stop
    debug "cleaning..."
    docker ps -a --filter "status=created" --filter "ancestor=doorbellian:${image_tag}" --format "{{.ID}}" | xargs -r docker rm
    docker ps -a --filter "status=exited" --filter "ancestor=doorbellian:${image_tag}" --format "{{.ID}}" | xargs -r docker rm
    if [[ -n "$(docker images -q doorbellian:${image_tag} 2> /dev/null)" ]]; then
        [[ ! -z "${image_tag}" ]] && docker image rm --force doorbellian:${image_tag} || docker image rm --force doorbellian
    fi
    docker images -f "dangling=true" --format "{{.ID}}" | xargs -r docker rmi
    docker system prune -f --filter "ancestor=doorbellian:${image_tag}" 2> /dev/null
    debug "cleaned."
}
