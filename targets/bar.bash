
description="build target followed by run target"

function target_bar () {
    target_build && target_run && return
    echo "[Error]: Build failed, exiting..."
    exit 100
}
