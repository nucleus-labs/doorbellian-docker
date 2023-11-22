
source 'targets/build.bash'
source 'targets/run.bash'

description="'build' target followed by 'run' target"


function target_bar () {
    target_build && target_run && return
    error ${BASH_SOURCE[0]} ${LINENO} "[Error]: Build failed, exiting..." 100
}
