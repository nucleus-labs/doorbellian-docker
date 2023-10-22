#!/usr/bin/env bash

# ================================================================================================
#                                            GLOBALS

declare -A valid_flags
declare -A valid_flag_names

declare -A flag_schedule

declare -a arguments
arguments+=($*)

declare -a builtin_targets

valid_arg_types=("any" "number" "string")

# ================================================================================================
#                                              UTILS
# (1: file; 2: line number; 3: error message; 4: exit code)
function error () {
    local file="$1"
    local line_number="$2"
    local message="$3"
    local code="${4:-1}"
    [[ -n "$message" ]] && echo "[ERROR][${file}][${line_number}][${code}]: ${message}" || echo "[ERROR][${file}][${line_number}][${code}]"
    exit ${code}
}
# trap 'error ${BASH_SOURCE[0]} ${LINENO}' ERR

# (1: array name (global); 2: array type (-a/-A))
function arr_max_length () {
    [[ -z "$1" ]]           && caller && echo "[ERROR]: Array name is empty!"                       && exit 70
    local arr_declare="$(declare -p "$1" 2>/dev/null)"
    [[ -z "${!1+x}" || "${arr_declare}" != "declare"* ]]                                            \
                            && caller && echo "[ERROR]: Variable '$1' does not exist!"              && exit 71
    [[ ! -v "$1"    || "${arr_declare}" != "declare -a"* && "${arr_declare}" != "declare -A"* ]]    \
                            && caller && echo "[ERROR]: Variable '$1' is not an array!"             && exit 72
    local -n arr="$1"
    local max_length=${arr[0]}

    for item in "${arr[@]}"; do
        max_length=$(( ${#item} > ${max_length} ? ${#item} : ${max_length} ))
    done

    echo ${max_length}
}

# (1: array name (global); 2: array type (-a/-A))
function arr_max_value () {
    [[ -z "$1" ]]           && caller && echo "[ERROR]: Array name is empty!"                       && exit 80
    local arr_declare="$(declare -p "$1" 2>/dev/null)"
    [[ -z "${!1+x}" || "${arr_declare}" != "declare"* ]]                                            \
                            && caller && echo "[ERROR]: Variable '$1' does not exist!"              && exit 81
    [[ ! -v "$1"    || "${arr_declare}" != "declare -a"* && "${arr_declare}" != "declare -A"* ]]    \
                            && caller && echo "[ERROR]: Variable '$1' is not an array!"             && exit 82
    [[ ! -z "$3" && "$3" != "-a" && "$3" != "-A" ]]                                                 \
                            && caller && echo "[ERROR]: Array type '$3' is not a valid type!"       && exit 83
    local -n arr="$1"
    local max_value=${arr[0]}

    for item in "${arr[@]}"; do
        [[ ! $2 =~ ^[0-9]+$ ]]  && caller && echo "[ERROR]: value '$2' is not a valid number!"      && exit 84
        max_value=$(( ${item} > ${max_value} ? ${item} : ${max_value} ))
    done
    echo ${max_value}
}

# (1: array name (global); 2: index to pop; 3: array type (-a/-A))
function arr_pop () {
    [[ -z "$1" ]] && {
        caller
        echo "[ERROR]: Array name is empty!" >&2
        exit 90
    }

    local arr_declare="$(declare -p "$1" 2>/dev/null)"

    [[ -z "${!1+x}" || "${arr_declare}" != "declare"* ]] && {
        caller
        echo "[ERROR]: Variable '$1' does not exist or is empty!" >&2
        exit 91
    }

    [[ ! -v "$1"    || "${arr_declare}" != "declare -a"* && "${arr_declare}" != "declare -A"* ]] && {
        caller
        echo "[ERROR]: Variable '$1' is not an array!" >&2
        exit 92
    }

    [[ ! $2 =~ ^[0-9]+$ ]]  && {
        caller
        echo "[ERROR]: Index '$2' is not a valid number!" >&2
        exit 93
    }

    [[ ! -v $1[$2] ]]       && {
        caller
        echo "[ERROR]: Array element at index $2 does not exist!" >&2
        exit 94
    }

    [[ ! -z "$3" && "$3" != "-a" && "$3" != "-A" ]] && {
        caller
        echo "[ERROR]: Array type '$3' is not a valid type!" >&2
        exit 95
    }
    eval "$1=(\${$1[@]:0:$2} \${$1[@]:$2+1})"
}

# ================================================================================================
#                                            BUILT-INS


# ================================================================================================
#                                       CORE FUNCTIONALITY
#  1: flag (single character); 2: name; 3: description; 4: priority;
#  5: argument name; 6: argument type; 7: argument description
function add_flag () {
    local flag="$1"
    local name="$2"
    local description="$3"
    local priority="$4"
    local argument="$5"
    local argument_type="$6"
    local arg_description="$7"

    # basic validations
    [[ x"${flag}" == x"" ]]             && caller && echo "[ERROR]: Flag cannot be empty!"                                          && exit 60
    [[ ${#flag} -gt 1 ]]                && caller && echo "[ERROR]: Flag '${flag}' is invalid! Flags must be a single character!"   && exit 61
    [[ x"${description}" == x"" ]]      && caller && echo "[ERROR]: Description for flag '${name}' cannot be empty!"                && exit 62
    [[ x"${priority}" == x"" ]]         && caller && echo "[ERROR]: Must provide a priority for flag '${name}'!"                    && exit 63
    [[ ! ${priority} =~ ^[0-9]+$ ]]     && caller && echo "[ERROR]: Priority <${priority}> for flag '${name}' is not a number!"     && exit 64
    [[ x"${argument}" != x"" && ! ${valid_arg_types[@]} =~ "${argument_type}" ]] \
                                        && caller && echo "[ERROR]: Flag argument type for '${name}':'${argument}' (${argument_type}) is invalid!"  && exit 65

    # more complex validations
    for key in "${!valid_flags[@]}"; do # iterate over keys
        [[ "${valid_flags[${key}]}" == "${flag}" ]]             && caller && echo "[ERROR]: Flag <${flag}> already registered!"                     && exit 66
    done

    for flag_name in "${!valid_flag_names[@]}"; do
        [[ "${valid_flag_names[${flag_name}]}" == "${name}" ]]  && caller && echo "[ERROR]: Flag name <${flag_name}> already registered!"           && exit 67
    done

    [[ x"${argument}" != x"" ]] && {
        [[ x"${argument_type}" == x"" ]]    && caller && echo "[ERROR]: Argument type must be provided for flag '${name}':'${argument}'"            && exit 68
        [[ x"${arg_description}" == x"" ]]  && caller && echo "[ERROR]: Argument description must be provided for flag '${name}':'${argument}'"     && exit 69
    }

    # register information
    [[ "${flag}" != "-" ]] && valid_flags["${flag}"]="${name}"
    
    # description="${description//\${/\\\${}"

    local packed="'${flag}' '${description//\'/\\\'}' '${priority//\'/\\\'}' '${argument//\'/\\\'}' '${argument_type//\'/\\\'}' '${arg_description//\'/\\\'}'"
    valid_flag_names[${name}]="${packed}"
}

# (1: flag (single character))
function validate_flag () {
    local flag="$1"
    local valid_flag_found=0

    # check if the supplied flag is valid
    for value in "${!valid_flags[@]}"; do
        if [[ "${flag}" != "-" && "${value}" == "${flag}" ]]; then
            valid_flag_found=1
            break
        fi
    done

    # if no valid flag matching the supplied flag is found, error
    if [[ ${valid_flag_found} -eq 0 ]]; then
        caller && echo "[ERROR]: '-${flag}' is not a valid flag."
        print_help
        exit 1
    else
        local flag_name="${valid_flags[${flag}]}"
        local function_name="${flag_name//-/_}"
        eval "flag_name_${function_name}"
    fi
}

# (1: flag name (string))
function validate_flag_name () {
    local flag_name="$1"
    local valid_flag_name_found=0

    # check if the supplied flag is valid
    for value in "${!valid_flag_names[@]}"; do
        if [[ "${value}" == "${flag_name}" || "${value}" == "${flag//-/_}" ]]; then
            valid_flag_name_found=1
            break
        fi
    done

    # if no valid flag matching the supplied flag is found, error
    if [[ ${valid_flag_name_found} -eq 0 ]]; then
        caller && echo "[ERROR]: '--${flag_name}' is not a valid flag name."
        print_help
        exit 1
    else
        local function_name="${flag_name//-/_}"
        eval "flag_name_${function_name}"
    fi
}

function validate_flags () {
    local arg="${arguments[0]}"

    if [[ "${arg:0:1}" != "-" ]]; then
        return
    fi

    arr_pop arguments 0

    if [[ "${arg:1:1}" != "-" ]]; then
        local flags=${arg}
        for (( i=1; i<${#flags}; i++ )); do
            validate_flag "${flags:$i:1}"
        done
    else
        validate_flag_name "${arg:2}"
    fi

    validate_flags
}

function validate_target () {
    target=${arguments[0]}
    valid_target_found=0

    arr_pop arguments 0

    [[ ! -f "targets/${target}.bash" ]] && {
        echo "Target file 'targets/${target}.bash' not found!" >&2
        exit 255
    }

    source "targets/${target}.bash"

    [[ $(type -t "target_${target}") != function ]] && {
        echo "Target function 'target_${target}' was not found in 'targets/${target}.bash'!" >&2
        exit 255
    }

    eval "target_${target}"
}

function execute_flags () {
    return
}

function is_builtin () {
    echo "n" # place-holder
}

declare     current_target
declare -a  target_arguments
declare -a  target_arg_types
declare -a  target_arg_descs

# (1: name; 2: type; 3: description)
function add_argument () {
    local name=$1
    local type_=$2
    local desc=$3

    local detected_any=0

    [[ x"${type_}" == x"" ]] && {
        detected_any=1
        type_="any"
    }

    [[ x"${name}" == x"" || x"${desc}" == x"" || x"${type_}" == x"" || ! ${valid_arg_types[@]} =~ "${type_}" ]] && {
        echo "add_argument usage is: 'add_argument \"<name>\" \"<${valid_arg_types[*]}>\" \"<description>\"'" >&2
        [[ ${detected_any} -eq 1 ]] && echo "(auto-detected type as \"any\")" >&2
        echo "What you provided:" >&2
        echo "add_argument \"${name}\" \"${type_}\" \"${desc}\"" >&2
        exit 255
    }

    local count=${#target_arguments[@]}

    target_arguments[$count]="${name}"
    target_arg_types[$count]="${type_}"
    target_arg_descs[$count]="${desc}"
}

function print_help () {
    local cols=$(tput cols)
    cols=$(( $cols > 22 ? $cols - 1 : 20 ))
    # TODO: print help for common flags

    echo "Usage: $0 [-<flag>[...]] [--<common flag> [...]] <target> [-<flag>[...]] [--<target-specific flag> [...]] <target argument [...]>"
    echo "       $0 --help"
    echo "       $0 --help <target>"
    echo

    # print help for targets
    if [[ ${#arguments[@]} -gt 0 ]]; then # `$0 --help <target>`?
        if [[ ! -f "targets/${arguments[0]}.bash" && $(is_builtin "${arguments[0]}") == "n" ]]; then
            caller
            echo "No such command '${arguments[0]}'"
            exit 255

        elif [[ $(is_builtin "${arguments[0]}") == "y" ]]; then
            # check builtin info
            return
        else
            local current_target="${arguments[0]}"
            source "targets/${current_target}.bash"
            arr_pop arguments 0

            local arg_count=${#target_arguments[@]}
            
            {
                echo "target: ${current_target};description:;${description}"
                echo ";;"
                echo "argument name |;argument type |;description"
                echo ";;"

                for (( i=0; i<${arg_count}; i++ )); do
                    # TODO: include target-specific flags
                    # echo "|-${flag_shortname}|${flag_name}||${flag_description}"
                    # for j=0,${flag_args[@]}; do
                    #     echo "||${flag_args[i][j]}|${flag}"
                    # done

                    echo "${target_arguments[i]};${target_arg_types[i]};${target_arg_descs[i]}"
                done
            } | column                                      \
                    --separator ';'                         \
                    --table                                 \
                    --output-width ${cols}                  \
                    --table-noheadings                      \
                    --table-columns "argument name,argument type,description"  \
                    --table-wrap description 
        fi
    else # iterate through targets and collect info ; `$0 -h` or `$0 --help`
        echo "Common Flags:"
        {
            echo ";name;priority;argument name;argument type   ;description"
            echo ";;;;;"
            for flag_name in "${!valid_flag_names[@]}"; do
            
                # echo "${flag_name}"
                local packed_flag_data="${valid_flag_names[${flag_name}]}"
                # echo "${packed_flag_data}"
                eval local flag_data=(${packed_flag_data})

                #  1: flag (single character); 2: name; 3: description; 4: priority;
                #  5: argument name; 6: argument type; 7: argument description
                local flag="${flag_data[0]}"
                local name="${flag_name}"
                local description="${flag_data[1]}"
                local priority="${flag_data[2]}"
                local argument="${flag_data[3]}"
                local argument_type="${flag_data[4]}"
                local arg_description="${flag_data[5]}"

                [[ "${flag}" == "-" ]] && flag="" || flag="-${flag}"

                echo "${flag};--${name};${priority};;;${description}"
                [[ x"${argument}" != x"" ]] && echo ";;;${argument};${argument_type};${arg_description}"
                echo ";;;;;"

            done
        } | column  --separator ';'                                                                             \
                    --table                                                                                     \
                    --output-width ${cols}                                                                      \
                    --table-noheadings                                                                          \
                    --table-columns "short name,long name,priority,argument name,argument type,description"     \
                    --table-right "short name,priority"                                                         \
                    --table-wrap description
        
        echo "Targets:"
        {
            echo ";;"
            for file in targets/*.bash; do
                current_target="${file##*/}"
                current_target="${current_target%.bash}"

                [[ "${current_target}" == "common" ]] && continue

                # echo "${current_target}" >&2
                
                target_arguments=()
                target_arg_types=()
                target_arg_descs=()

                source ${file}

                local arg_count=${#target_arguments[@]}

                echo "${current_target};${arg_count};${description}"
                echo ";;"
            done
        } | column                                                  \
                --separator ';'                                     \
                --table                                             \
                --output-width ${cols}                              \
                --table-columns "subcommand,arg count,description"  \
                --table-wrap description 
    fi
}
# print_help

add_flag "-" "help" "prints this menu" 0
function flag_name_help () {
    print_help
    exit 0
}
