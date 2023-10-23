

description="use buildg to step through the dockerfile"

function target_debug () {
    buildg debug --file ${dockerfile} .
    exit 0
}
