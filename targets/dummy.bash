

description="you are, without a doubt, the biggest dummy I've ever seen"

add_argument "dummy1" "int"     "a dummy int"
add_argument "dummy2" "float"   "a dummy float"
add_argument "dummy3" "string"  "a dummy string"

function target_dummy () {
    [[ ${debug_mode} -eq 1 ]] && echo
    echo "Hi dummy!"
    echo "dummy1: $1"
    echo "dummy2: $2"
    echo "dummy3: $3"
}
