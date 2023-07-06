#!/bin/bash

# ================================================================================================

valid_targets=("build" "run" "bar")
valid_target_found=0

# ================================================================================================

# was exactly one argument supplied? if not, print usage and error.
if [ $# -ne 1 ]; then
    echo "Usage: $0 <$(IFS=/; echo "${valid_targets[*]}")>"
    exit 2
fi

# ================================================================================================

target=$1

# check if the supplied target is valid
for value in "${valid_targets[@]}"; do
    if [ "$target" = "$value" ]; then
        valid_target_found=1
        break
    fi
done

# if no valid target matching the supplied target is found, error
if [ $valid_target_found -eq 0 ]; then
    echo "Error: '$target' is not a valid target."
    echo "Usage: $0 <$(IFS=/; echo "${valid_targets[*]}")>"
    exit 2
fi

# ================================================================================================

if [ "$target" = "build" ] || [ "$target" = "bar" ]; then
    docker build -t doorbellian:dev .
fi

if [ "$target" = "run" ] || [ "$target" = "bar" ]; then
    docker run -it \
        -p 1935:1935 \
        -p 8000:8000 \
        -p 8001:8001 \
        -p 8554:8554 \
        -p 8888:8888 \
        -p 8889:8889 \
        doorbellian:dev
fi
