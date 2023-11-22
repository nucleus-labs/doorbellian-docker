
source 'targets/build.bash'
source 'targets/extract.bash'

description="'build' target followed by 'extract' target"


function target_bae () {
    target_build
    target_extract
}
