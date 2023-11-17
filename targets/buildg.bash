
description="use buildg to step through the dockerfile"


function target_buildg () {
    buildg debug --file ${dockerfile} .
    exit 0
}
