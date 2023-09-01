#!/usr/bin/env bash

declare -A valid_flag_names
declare -A valid_flag_data
declare -A valid_flag_priorities
declare -a valid_targets
declare -a valid_target_descriptions


#  1: flag (single character); 2: flag name; 3: flag description;
#  4: flag priority; 5: flag arguments (semicolon delimiter); 6: flag argument descriptions (semicolon delimiter)
function add_flag () {
    local flag="$1"
    local name="$2"
    local description="$3"
    local priority=$4
    local arguments="($5)"
    local arg_descriptions="($6)"

    [[ ${#flag} -eq 0 ]]                && caller && echo "[ERROR]: Flags cannot be empty!"                                         && exit 60
    [[ ${#flag} -gt 1 ]]                && caller && echo "[ERROR]: Flag '${flag}' is invalid! Flags must be a single character!"   && exit 61
    [[ "$description"       == *'|'* ]] && caller && echo "[ERROR]: Description cannot contain '|'"                                 && exit 62
    [[ "$arguments"         == *'|'* ]] && caller && echo "[ERROR]: Arguments cannot contain '|'"                                   && exit 63
    [[ "$arg_descriptions"  == *'|'* ]] && caller && echo "[ERROR]: Argument descriptions cannot contain '|'"                       && exit 64

    [[ "${flag}" != "-" ]] && valid_flag_names["${flag}"]="${name}"
    valid_flag_data["${flag}"]="description=${description}|arguments=${arguments}|arg_descriptions=${arg_descriptions}"
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
    for value in "${!valid_flag_names[@]}"; do
        if [[ "$value" == "$flag" ]]; then
            valid_flag_found=1
            break
        fi
    done

    # if no valid flag matching the supplied flag is found, error
    if [ $valid_flag_found -eq 0 ]; then
        caller && echo "[ERROR]: '-$flag' is not a valid flag."
        print_help
        exit 1
    else
        eval "flag_${flag}"
    fi
}

# (1: flag name (string))
function validate_flag_name () {
    local flag_name="$1"
    local valid_flag_name_found=0

    # check if the supplied flag is valid
    for value in "${valid_flag_data[@]}"; do
        if [ "$value" = "$flag_name" ]; then
            valid_flag_name_found=1
            break
        fi
    done

    # if no valid flag matching the supplied flag is found, error
    if [ $valid_flag_name_found -eq 0 ]; then
        caller && echo "[ERROR]: '--$flag_name' is not a valid flag."
        print_help
        exit 1
    else
        eval "flag_name_${flag_name}"
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

    # check if the supplied target is valid
    for value in "${valid_targets[@]}"; do
        if [ "$target" = "$value" ]; then
            valid_target_found=1
            break
        fi
    done

    # if no valid target matching the supplied target is found, error
    if [ $valid_target_found -eq 0 ]; then
        caller && echo "[ERROR]: '$target' is not a valid target."
        print_help
        exit 2
    else
        eval "target_${target}"
    fi
}

function execute_flags () {
    return
}

function print_help () {
    echo "[ERROR]: print_help is currently broken!"
    exit 0

    # needs to be adapted to the changes made to the over-arching script
    # TODO: Use renamed/restructured arrays
    # TODO: implement usage of flag data

    local usage_flags=""
    local usage_targets=""

    local formatted_description=""
    local formatted_description_linecount=0

    # (1: description; 2: left-padding, 3: line-width)
    function format_description () {
        [[ -z "$1" ]]           && caller && echo "[ERROR]: description is empty!"                  && exit 30
        [[ ! $2 =~ ^[0-9]+$ ]]  && caller && echo "[ERROR]: left-padding is not a valid number!"    && exit 31
        [[ ! $3 =~ ^[0-9]+$ ]]  && caller && echo "[ERROR]: line width is not a valid number!"      && exit 32

        formatted_description=""
        formatted_description_linecount=1
        local description="$1"
        local left_padding=$( printf "%${2}s" )
        local line_width=$3

        local current_line=""

        IFS=" "
        read -ra words <<< "$description"
        IFS=$IFS_DEFAULT

        local used_left_padding="$left_padding"

        for word in "${words[@]}"; do
            if (( ${#used_left_padding} + ${#current_line} + ${#word} + 1 > $line_width )); then
                (( ${formatted_description_linecount} == 1 )) && used_left_padding=""
                formatted_description="${formatted_description}${used_left_padding}${current_line}\n"
                current_line="${word}"
                formatted_description_linecount=$(($formatted_description_linecount+1))
                used_left_padding="$left_padding"
            else
                if [ -z "$current_line" ]; then # true for i=0
                    current_line="$word"
                else
                    current_line="$current_line $word"
                fi
            fi
        done

        (( ${formatted_description_linecount} == 1 )) && used_left_padding=""
        formatted_description="${formatted_description}${used_left_padding}${current_line}\n"
    }

    local max_flag_width=$(   arr_max_length valid_flag_data    \-A )
    local max_target_width=$( arr_max_length valid_targets      \-a )

    local max_width=$(($max_flag_width > $max_target_width ? $max_flag_width : $max_target_width ))

    for ((i = 0; i < ${#valid_flags[@]}; i++)); do
        local flag="${valid_flags[i]}"
        local flag_name="${valid_flag_names[i]}"

        local flag_padding=$((${#flag_name} <= $max_width ? $max_width - ${#flag_name} + 1 : 1))
        local flag_spaces=$(printf "%${flag_padding}s")

        local line="    -${flag}   | --${flag_name}${flag_spaces}| "
        [[ ${flag} == "-" ]] && line="           --${flag_name}${flag_spaces}| "

        format_description "${valid_flag_descriptions[i]}" ${#line} $((${cols} - 4))

        usage_flags="${usage_flags}${line}${formatted_description}\n"
    done

    format_description=""

    for ((i = 0; i < ${#valid_targets[@]}; i++)); do
        local target="${valid_targets[i]}"

        local target_padding=$((${#target} < $max_width ? $max_width - ${#target} + 10 : 1))
        local target_spaces=$(printf "%${target_padding}s" " ")

        local line="    ${target}${target_spaces}| "

        format_description "${valid_target_descriptions[i]}" ${#line} $((${cols} - 4))
        
        usage_targets="${usage_targets}${line}${formatted_description}\n"
    done

    local small_cols=$(( $cols - 8))
    local short_line=$(printf '%*s\n' "$small_cols" | tr ' ' '-')
    echo "Usage: $0 [flags, ...] <target> [target_arguments...]"
    echo ""
    echo "A helpful tool for doorbellian development"
    echo ""
    echo "Maintained by Maxine Alexander <max.alexander3721@gmail.com>"
    echo ""
    echo "----${short_line}----"
    echo ""
    local target_spaces=$(printf "%$(($max_width - 1))s" " ")
    echo "    flag | name${target_spaces}| description"
    echo "    ${short_line}"
    echo -e   "$usage_flags"
    echo "----${short_line}----"
    target_spaces=$(printf "%$(($max_width + 4))s" " ")
    echo "    target${target_spaces}| description"
    echo "    ${short_line}"
    echo -e   "$usage_targets"
    echo ""
}

add_flag "h" "help" "prints this menu" 0
function flag_h () {
    print_help
    exit 0
}
