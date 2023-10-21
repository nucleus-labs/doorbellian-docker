

description="extract files from a docker container"

function target_extract () {
    if [[ -n "$(docker images -q doorbellian:${image_tag} 2> /dev/null)" ]]; then
        local extracts=(${arguments[@]})
        local container_id=$(get_container_id)

        for extracted in "${extracts[@]}"; do
            IFS=';' read -ra extracted_parts <<< "${extracted}"
            local _from="${extracted_parts[0]}"
            local _to="tmp/${extracted_parts[0]}"
            [[ ${#extracted_parts} -gt 1 ]] && _to="tmp/${extracted_parts[1]}"
            mkdir -p $(dirname "${_to}")
            echo "Extracting ${container_id:0:8}:'${_from}' to '${_to}'"
            docker cp "${container_id}:${_from}" "${_to}" 2>&1 >/dev/null
            echo "Done Extracting."
        done
        [[ ${created} -eq 1 ]] && docker rm -v ${container_id} >/dev/null
    else
        echo "No valid images found to extract from! Please run '${SCRIPT_NAME} --tag ${image_tag} build'"
    fi
}
