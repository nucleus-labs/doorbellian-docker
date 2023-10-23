

description="inject files into a docker container"

function target_inject () {
    if [[ -n "$(docker images -q doorbellian:${image_tag} 2> /dev/null)" ]]; then
        local inject=(${arguments[@]})
        local container_ids=($(docker ps -a --filter "ancestor=doorbellian:${image_tag}" --format '{{.ID}}' 2>/dev/null))
        local container_id=""
        local created=0

        [[ ${#container_ids[@]} -gt 1 ]] && IFS=',' echo "[ERROR]: too many available containers: (${container_id[*]})" && exit 20
        [[ ${#container_ids[@]} -eq 0 ]] && created=1 && container_id="$(docker create doorbellian:${image_tag})" || container_id=${container_ids[0]}

        IFS=';' read -ra injected_parts <<< "${inject}"
        local _from="${injected_parts[0]}"
        local _to="${injected_parts[0]}"
        [[ ${#injected_parts} -gt 1 ]] && _to="${injected_parts[1]}"
        echo "Injecting '${_from}' to ${container_id:0:8}:'${_to}'"
        docker cp "${_from}" ${container_id}:"${_to}" 2>&1 >/dev/null
        echo "Done Injecting."

        [[ ${created} -eq 1 ]] && docker rm -v ${container_id} 2>&1 >/dev/null
    else
        echo "No valid images found to extract from! Please run '${SCRIPT_NAME} --tag ${image_tag} --dockerfile ${dockerfile} build'"
    fi
}
