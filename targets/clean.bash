

description="clean out containers and images, and dangling images related to doorbellian's active tag"

PURGE=0

add_flag '-' "purge" "clean ALL doorbellian docker materials from the system." 0
function flag_name_purge () {
    PURGE=1
    debug "cleaning all images"
}

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
    if [[ ${PURGE} -eq 0 ]]; then
        docker system prune -f --filter "label=purpose=doorbellian" --filter "label=_tag=${image-tag}" 2> /dev/null
    else
        docker system prune -f --filter "label=purpose=doorbellian" 2> /dev/null
    fi
    debug "cleaned."
}
