#!/usr/bin/env bash

# ================================================================================================
#                                            GLOBALS

declare -A valid_flags
declare -a valid_flag_names

declare -A valid_flag_priorities

declare -A valid_flag_names_descriptions
declare -A valid_flag_names_arguments

declare -a flag_schedule


declare -a valid_targets_arguments
declare -a valid_targets_arguments_descriptions


declare -a arguments
arguments+=($*)

declare -a builtin_targets

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
#  1: flag (single character); 2: flag name; 3: flag description;
#  4: flag priority; 5: flag argument name; 6: flag argument description
function add_flag () {
    local flag="$1"
    local name="$2"
    local description="'$3'"
    local priority=$4
    local argument="$5"
    local arg_descriptions="$6"

    # basic validations
    [[ ${#flag} -eq 0 ]]                && caller && echo "[ERROR]: Flags cannot be empty!"                                         && exit 60
    [[ ${#flag} -gt 1 ]]                && caller && echo "[ERROR]: Flag '${flag}' is invalid! Flags must be a single character!"   && exit 61
    [[ -z "${description}" ]]           && caller && echo "[ERROR]: Description for flag '${name}' cannot be empty!"                && exit 62
    [[ -z "${priority}" ]]              && caller && echo "[ERROR]: Must provide a priority for flag '${name}'!"                    && exit 63
    [[ ! ${priority} =~ ^[0-9]+$ ]]     && caller && echo "[ERROR]: Priority <${priority}> for flag '${name}' is not a number!"     && exit 64

    # more complex validations
    for key in "${!valid_flags[@]}"; do # iterate over keys
        [[ "${keys[i]}" == "${flag}" ]]         && caller && echo "[ERROR]: Flag <${flag}> already registered!"             && exit 65
    done

    for flag_name in "${valid_flag_names[@]}"; do
        [[ "${flag_name[i]}" == "${name}" ]]    && caller && echo "[ERROR]: Flag name <${flag_name}> already registered!"   && exit 66
    done

    # register information
    [[ "${flag}" == "-" ]] || valid_flags["${flag}"]="${name}"
    
    valid_flag_names+=("${name}")
    valid_flag_names_descriptions["${name}"]="${description}"
    # valid_flag_names_arguments["${name}"]="${argument}"
    valid_flag_priorities["${priority}"]=${priority}
}

# (1: target name; 2: target description)
function add_target () {
    [[ ${#1} -eq 0 ]]   && caller && echo "[ERROR]: Targets cannot be empty!" && exit 50
    valid_targets+=("$1")
    valid_target_descriptions+=("$2")
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
        # print_help
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
    for value in "${valid_flag_names[@]}"; do
        if [[ "${value}" == "${flag_name}" || "${value}" == "${flag//-/_}" ]]; then
            valid_flag_name_found=1
            break
        fi
    done

    # if no valid flag matching the supplied flag is found, error
    if [[ ${valid_flag_name_found} -eq 0 ]]; then
        caller && echo "[ERROR]: '--${flag_name}' is not a valid flag name."
        # print_help
        exit 1
    else
        # parameter expansion
        eval "flag_name_${flag_name//-/_}"
    fi
}

function validate_flags () {
    local arg="${arguments[0]}"

    if [[ "${arg:0:1}" != "-" ]]; then
        return
    fi

    arr_pop arguments 0

    if [[ "${arg:1:1}" != "-" ]]; then
        local flags=$arg
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

# function print_help () {
#     local cols=$(tput cols)

#     # TODO: implement usage of flag data

#     local flags=(${!valid_flag_names[@]})
#     local flag_names=(${valid_flag_names[@]})

#     local usage_flags=""
#     local usage_targets=""

#     local formatted_description=""
#     local formatted_description_linecount=0

#     # (1: description; 2: left-padding, 3: line-width)
#     function format_description () {
#         [[ -z "$1" ]]           && caller && echo "[ERROR]: description is empty!"                  && exit 30
#         [[ ! $2 =~ ^[0-9]+$ ]]  && caller && echo "[ERROR]: left-padding is not a valid number!"    && exit 31
#         [[ ! $3 =~ ^[0-9]+$ ]]  && caller && echo "[ERROR]: line width is not a valid number!"      && exit 32

#         formatted_description=""
#         formatted_description_linecount=1
#         local description="$1"
#         local left_padding=$( printf "%${2}s" )
#         local line_width=$3

#         local current_line=""

#         IFS=' ' read -ra words <<< "$description"

#         local used_left_padding="$left_padding"

#         for word in "${words[@]}"; do
#             if (( ${#used_left_padding} + ${#current_line} + ${#word} + 1 > $line_width )); then
#                 (( ${formatted_description_linecount} == 1 )) && used_left_padding=""
#                 formatted_description="${formatted_description}${used_left_padding}${current_line}\n"
#                 current_line="${word}"
#                 formatted_description_linecount=$(($formatted_description_linecount+1))
#                 used_left_padding="$left_padding"
#             else
#                 if [[ -z "$current_line" ]]; then # true for i=0
#                     current_line="$word"
#                 else
#                     current_line="$current_line $word"
#                 fi
#             fi
#         done

#         (( ${formatted_description_linecount} == 1 )) && used_left_padding=""
#         formatted_description="${formatted_description}${used_left_padding}${current_line}\n"
#     }

#     # flag_arg_widths=()
#     # for flag_data in "${valid_flag_data[@]}"; do
#     #     local flag_data_parts=
#     #     local description=
#     #     local arguments=
#     #     local arg_descriptions=

#     #     IFS='|' read -ra flag_data_parts <<< "${flag_data}"

#     #     for part in "${flag_data_parts[@]}"; do
#     #         eval "$part"
#     #     done

#     #     for arg in "${arguments[@]}"; do
#     #         max_flag_arg_width+=(${#arg})
#     #     done
#     # done



#     local max_flag_width=$(     arr_max_length flag_names     \-A )
#     # local max_flag_arg_width=$( arr_max_value flag_arg_widths )
#     local max_target_width=$(   arr_max_length valid_targets  \-a )

#     local max_width=$(($max_flag_width > $max_target_width ? $max_flag_width : $max_target_width ))

#     for ((i = 0; i < ${#flags[@]}; i++)); do
#         local flag="${flags[$i]}"
#         local flag_name="${flag_names[$i]}"
#         local flag_data="${valid_flag_data[$flag_name]}"

#         local flag_padding=$((${#flag_name} <= $max_width ? $max_width - ${#flag_name} + 1 : 1))
#         local flag_spaces=$(printf "%${flag_padding}s")

#         local line="    -${flag}   | --${flag_name}${flag_spaces}| "
#         echo "${flag}"
#         [[ ${flag} == "-" ]] && line="           --${flag_name}${flag_spaces}| "

#         local flag_data_parts=
#         local description=
#         local arguments=
#         local arg_descriptions=

#         IFS='|' read -ra flag_data_parts <<< "${flag_data}"

#         for part in "${flag_data_parts[@]}"; do
#             eval "$part"
#         done

#         format_description "${description}" ${#line} $((${cols} - 4))

#         usage_flags+="${line}${formatted_description}\n"

#         # for ((i = 0; i < ${#arguments}; i++)); do
#         #     local argument="${arguments[$i]}"
#         #     local arg_description=""
#         #     line="$(printf "%11s") ${argument}"

#         # done
#     done

#     format_description=""

#     for ((i = 0; i < ${#valid_targets[@]}; i++)); do
#         local target="${valid_targets[$i]}"

#         local target_padding=$((${#target} < $max_width ? $max_width - ${#target} + 10 : 1))
#         local target_spaces=$(printf "%${target_padding}s" " ")

#         local line="    ${target}${target_spaces}| "

#         format_description "${valid_target_descriptions[i]}" ${#line} $((${cols} - 4))
        
#         usage_targets="${usage_targets}${line}${formatted_description}\n"
#     done

#     local small_cols=$(( $cols - 8))
#     local short_line=$(printf '%*s\n' "$small_cols" | tr ' ' '-')
#     echo "Usage: $0 [flags, ...] <target> [target_arguments...]"
#     echo ""
#     echo "A helpful tool for doorbellian development"
#     echo ""
#     echo "Maintained by Maxine Alexander <max.alexander3721@gmail.com>"
#     echo ""
#     echo "----${short_line}----"
#     echo ""
#     local target_spaces=$(printf "%$(($max_width - 1))s" " ")
#     echo "    flag | name${target_spaces}| description"
#     echo "    ${short_line}"
#     echo -e   "$usage_flags"
#     echo "----${short_line}----"
#     target_spaces=$(printf "%$(($max_width + 4))s" " ")
#     echo "    target${target_spaces}| description"
#     echo "    ${short_line}"
#     echo -e   "$usage_targets"
# }

function is_builtin () {
    echo "n" # place-holder
}

valid_arg_types=("any" "number" "string")
current_target=

declare -a target_arguments
declare -a target_arg_types
declare -a target_arg_descs

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

    [[ x"${name}" != x"" && x"${desc}" != x"" && ${valid_arg_tyes[@]} =~ "${type_}" ]] && {
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
        {
            # echo "subcommand|name_short|name_long|type|description"
            for file in targets/*.bash; do
                current_target="${file##*/}"
                current_target="${current_target%.bash}"

                [[ "${current_target}" == "common" ]] && continue

                # echo "${current_target}" >&2
                
                target_arguments=()
                target_arg_types=()
                target_arg_descs=()

                source ${file}

                echo "${current_target};${description}"
                echo ";"
            done
        } | column                                      \
                --separator ';'                         \
                --table                                 \
                --output-width ${cols}                  \
                --table-columns subcommand,description  \
                --table-wrap description 
    fi
}
# print_help

add_flag "-" "help" "prints this menu" 0
function flag_name_help () {
    print_help
    exit 0
}
