#!/usr/bin/env bash
# Copyright (c) 2017 Jean-Raphaël Gaglione

if [ -n "${SNAIL_PATH+_}" ]; then
    [ "$SNAIL_PATH" != "$(dirname "${BASH_SOURCE[0]}")" ] && {
        echo "SNAIL_PATH already defined"
        [[ "${BASH_SOURCE[0]}" == "$0" ]] && return 1 || exit 1
    } >&2
else
    SNAIL_PATH="$(dirname "${BASH_SOURCE[0]}")"
    declare -r SNAIL_PATH
fi
[[ "${BASH_SOURCE[0]}" == "$0" ]] || {
    nohup "$SNAIL_PATH/clean.sh" --wait $$ >/dev/null 2>&1 &
}

export MPS1=${MPS1-'\[\e[01;38;5;202m\]mill\[\e[m\]:\[\e[01;34m\]\W\[\e[m\]\$ '}
export MPS2=${MPS2-'\[\e[01;38;5;202m\]>\[\e[m\] '}


# track [-t|-T TIMEOUT] [-o|-a] [-g|-w] FILE...
function track {
    local -i and=0
    local -i glob=0
    local -i delay=-1
    local timeout=""
    if getopt --test > /dev/null; [[ $? -eq 4 ]]; then
        local __OPTS__
        __OPTS__="$(getopt --name "${FUNCNAME[0]}" \
            --options "+oagwt:T:" \
            --longoptions "or,and,glob,wildcard,timeout:,delay:" \
            -- "$@")" || return 1
        eval set -- "$__OPTS__"
    fi
    while [[ $# -ge 1 ]]; do # opts
        case "$1" in
        -o|--or ) shift; and=0 ;;
        -a|--and ) shift; and=1 ;;
        -g|--glob ) shift; glob=1 ;;
        -w|--wildcard ) shift; glob=1 ;;
        -t|--timeout ) shift
            [ "$1" -ge "0" ] 2>/dev/null || {
                echo "${FUNCNAME[0]} : invalid positive integer expression ‘$1’"; return 1
            } >&2
            timeout="$1"; shift ;;
        -T|--delay ) shift
            [ "$1" -ge "0" ] 2>/dev/null || {
                echo "${FUNCNAME[0]} : invalid positive integer expression ‘$1’"; return 1
            } >&2
            delay="$1"; shift ;;
        -- ) shift; break ;;
        * ) break ;;
        esac
    done
    local -a files
    local -A modif
    # RECORD INFOS
    if ((glob)); then
        eval "$(shopt -s nullglob; files=($@); declare -p files)"
    else
        files=("$@")
    fi
    if [[ $# -lt 1 ]]; then
        files=(./*)
        glob=1
    fi
    for file in "${files[@]}"; do
        modif[$file]=$(stat -c "%Z" "$file" 2>/dev/null) # || {
        #     echo "${FUNCNAME[0]} : cannot track ‘$file’"; return 1
        # } >&2
    done
    [ -n "$timeout" ] && ((timeout+=$(date +%s)))
    local list
    # TRACK CHANGES
    ((delay>=0)) && sleep "$delay" && timeout=${timeout:-0}
    local -i count
    while true; do
        count=0
        for file in "${!modif[@]}"; do
            if ! [ "$(stat -c "%Z" "$file" 2>/dev/null)" = "${modif[$file]}" ] 2>/dev/null; then
                ((and)) && unset modif[$file] || return 0
            else
                count+=1
            fi
        done
        ((count)) || return 0
        if ((glob && ! and)); then
            eval "$(shopt -s nullglob; list=($@); declare -p list)"
            [[ $# -lt 1 ]] && list=(./*)
            [ ${#list[@]} -eq ${#files[@]} ] || return 0
            for file in "${!files[@]}"; do
                [ "${list[$file]}" = "${files[$file]}" ] || return 0
            done
        fi
        [ -n "$timeout" ] && (($(date +%s)>=timeout)) && return 255
        sleep 0.2
    done
}


# mill [-p PERIOD|-i] [-q|-b|-B] [-M] [-T TIMEOUT] [-F FILE] [-C CONDITION] COMMAND...
function mill {
    local __STATUS__=0
    local __period__ __mode__
    local __timeout__
    local -i __manual__=0
    local -a __tracked_files__=()
    local -a __conditions__=()
    local -i __CONDS__=0
    if getopt --test > /dev/null; [[ $? -eq 4 ]]; then
        local __OPTS__
        __OPTS__="$(getopt --name "${FUNCNAME[0]}" \
            --options "+p:iT:F:C:MqbB" \
            --longoptions "period:,instant,timeout:,track-file:,condition:,manual,quiet,unbuffered,buffered" \
            -- "$@")" || return 1
        eval set -- "$__OPTS__"
    fi
    while [[ $# -ge 1 ]]; do # opts
        case "$1" in
        -p|--period ) shift
            [[ "$1" =~ ^[+]?([0-9]*[.]?[0-9]+|[0-9]+[.])([eE][-+]?[0-9]+)?$ ]] || {
                echo "${FUNCNAME[0]} : invalid time interval ‘$1’"; return 1
            } >&2
            __period__="$1"; shift ;;
        -i|--instant ) shift
            __period__=0 ;;
        -M|--manual ) shift; __CONDS__+=1
            __manual__=1 ;;
        -T|--timeout ) shift; __CONDS__+=2
            [ "$1" -ge "0" ] 2>/dev/null || {
                echo "${FUNCNAME[0]} : invalid positive integer expression ‘$1’"; return 1
            } >&2
            __timeout__="$1"; shift ;;
        #-V|--track-var ) shift; __CONDS__+=4
        -F|--track-file ) shift; __CONDS__+=8
            __tracked_files__[${#__tracked_files__[@]}]="$1"; shift ;;
        -C|--condition ) shift; __CONDS__+=16
            __conditions__[${#__conditions__[@]}]="$1"; shift ;;
        -q|--quiet ) shift
            __mode__=0 ;;
        -b|--unbuffered ) shift
            __mode__=1 ;;
        -B|--buffered ) shift
            __mode__=2 ;;
        -- ) shift; break ;;
        * ) break ;;
        esac
    done
    [ -t 1 ] || __mode__=${__mode__-0} # non interactive
    __period__=${__period__-0.2}
    if ! ((__CONDS__)); then # no conditions
        __mode__=${__mode__-2}
    else # conditions specified
        __mode__=${__mode__-1}
    fi
    local -r __buffer__="/dev/shm/mill-$$-$RANDOM$RANDOM"
    local -r __period__ __mode__
    local -r __CONDS__ __timeout__ __tracked_files__ __conditions__
    # ((__mode__==2)) && ({ # cleaner
    #     while kill -s 0 $$; do
    #         sleep 9
    #     done
    #     rm "$__buffer__"
    # }&) >/dev/null 2>&1
    local __ps1__ __ps2__ __first_line__ __line__ __time_out__
    local __file__ __condition__ # iterators
    local -i __BREAK__
    local -a __files__ __files2__
    local -A __file_modif__
    # CYCLE
    while true; do
        # RECORD CONDITIONS INFOS
        # record `-T`
        [ -n "$__timeout__" ] && __time_out__=$(($(date +%s)+__timeout__))
        # record `-F`
        __file_modif__=()
        eval "$(shopt -s nullglob; __files__=(${__tracked_files__[@]}); \
            declare -p __files__)" || __files__=()
        for __file__ in "${__files__[@]}"; do
            __file_modif__[$__file__]=$(stat -c "%Z" "$__file__" 2>/dev/null)
        done
        # EXECUTE COMMAND
        unset __first_line__
        case $__mode__ in
        0 ) # QUIET
            for __BREAK__ in 1 0; do
                ((__BREAK__)) || break
                (exit "$__STATUS__"); eval -- "$@"; __STATUS__="$?"
            done
            ;;
        1 ) # UNBUFFERED
            clear
            __ps1__=$(PS1="$MPS1" "$BASH" --norc -i </dev/null 2>&1 | sed -n 's/^\(.*\)exit$/\1/p;')
            __ps2__=$(PS1="$MPS2" "$BASH" --norc -i </dev/null 2>&1 | sed -n 's/^\(.*\)exit$/\1/p;')
            echo -n "$__ps1__"
            while IFS='' read -r __line__; do
                [ -n "$__line__" ] || continue
                [ -z "$__first_line__" ] && __first_line__="no" || echo -n "$__ps2__"
                echo "$__line__"
            done <<< "$@"
            [ -z "$__first_line__" ] && echo
            for __BREAK__ in 1 0; do
                ((__BREAK__)) || break
                (exit "$__STATUS__"); eval -- "$@"; __STATUS__="$?"
            done
            ;;
        2 ) # BUFFERED
            {
                __ps1__=$(PS1="$MPS1" "$BASH" --norc -i </dev/null 2>&1 | sed -n 's/^\(.*\)exit$/\1/p;')
                __ps2__=$(PS1="$MPS2" "$BASH" --norc -i </dev/null 2>&1 | sed -n 's/^\(.*\)exit$/\1/p;')
                echo -n "$__ps1__"
                while IFS='' read -r __line__; do
                    [ -n "$__line__" ] || continue
                    [ -z "$__first_line__" ] && __first_line__="no" || echo -n "$__ps2__"
                    echo "$__line__"
                done <<< "$@"
                [ -z "$__first_line__" ] && echo
                for __BREAK__ in 1 0; do
                    ((__BREAK__)) || break
                    (exit "$__STATUS__"); eval -- "$@"; __STATUS__="$?"
                done
            } &> "$__buffer__" # TODO: try a PTY
            clear
            cat "$__buffer__"
            rm "$__buffer__" # does not works if interrupted
            ;;
        esac
        ((__BREAK__)) && break;
        # LATENCY STAGE
        while true; do
            # test `-T`
            [ -n "$__timeout__" ] && (($(date +%s)>=__time_out__)) && break
            # test `-F`
            for __file__ in "${!__file_modif__[@]}"; do
                [ "$(stat -c "%Z" "$__file__" 2>/dev/null)" = "${__file_modif__[$__file__]}" ] 2>/dev/null ||
                    break 2
            done
            eval "$(shopt -s nullglob; __files2__=(${__tracked_files__[@]}); \
                declare -p __files2__)" || __files2__=()
            [ ${#__files2__[@]} -eq ${#__files__[@]} ] || break
            for __file__ in "${!__files__[@]}"; do
                [ "${__files2__[$__file__]}" = "${__files__[$__file__]}" ] || break 2
            done
            # test `-C`
            for __condition__ in "${__conditions__[@]}"; do
                for __BREAK__ in 1 0; do
                    ((__BREAK__)) || break
                    (exit "$__STATUS__"); eval -- "$__condition__" && break 3
                done
                ((__BREAK__)) && break 2
            done
            # wait `PERIOD` / test `-M`
            ((__CONDS__==1)) && read -r && break
            if ((__manual__)); then
                read -t "$__period__" -r
                [ $? -ge 128 ] || break # TODO: case __period__==0
            else
                sleep "$__period__"
            fi
            ((__CONDS__)) || break
        done
        # END OF CYCLE
    done
}


# scale VAR [MIN] [MAX]
function scale {
    zenity --version &>/dev/null || {
        echo "${FUNCNAME[0]} : zenity cannot be launched"; return 2
    } >&2
    echo dummy | read -r "$1" &>/dev/null || {
        echo "${FUNCNAME[0]} : invalid identifier ‘$1’"; return 1
    } >&2
    local -a __val__=(/dev/shm/scale-$$-$1-*)
    [ ${#__val__[@]} -ge 4 ] && {
        echo "${FUNCNAME[0]} : too many open scales for ‘$1’"; return 3
    } >&2
    local -a __val__=(/dev/shm/scale-$$-*)
    [ ${#__val__[@]} -ge 16 ] && {
        echo "${FUNCNAME[0]} : too many open scales for this terminal"; return 3
    } >&2
    local -r __shared__="/dev/shm/scale-$$-$1-$RANDOM$RANDOM"
    local -i __val__
    local __prev__=${!1}
    local __min__=${2-0}
    local __max__=${3-100}
    local __step__=1
    [ "$__min__" -eq "$__min__" ] 2>/dev/null || {
        echo "${FUNCNAME[0]} : invalid integer expression ‘$__min__"; return 1
    } >&2
    [ "$__max__" -eq "$__max__" ] 2>/dev/null || {
        echo "${FUNCNAME[0]} : invalid integer expression ‘$__max__’"; return 1
    } >&2
    [ $# -le 3 ] || {
        echo "${FUNCNAME[0]} : too many arguments"; return 1
    } >&2
    if [ "$__min__" -gt "$__max__" ]; then
        __val__="$__min__"
        __min__="$__max__"
        __max__="$__val__"
    fi
    [ "$__min__" -eq "$__max__" ] && {
        echo "${FUNCNAME[0]} : bounds must be different values"; return 1
    } >&2
    __val__=$__min__
    [ "$__prev__" -eq "$__prev__" ] 2>/dev/null && __val__=$__prev__
    [ "$__val__" -lt "$__min__" ] && __val__=$__min__
    [ "$__val__" -gt "$__max__" ] && __val__=$__max__
    echo "$__val__" > "$__shared__"
    ({ # pull values while file exists (drop values when too slow)
        local val="$__val__"
        local oldval="not $val"
        while [ -n "$val" ]; do
            if [ "$val" != "$oldval" ]; then
                gdb --batch-silent -p "$$" \
                    -ex "set bind_variable(\"$1\", \"$val\", 0)" \
                    2>/dev/null # thanks BeniBela
                oldval="$val"
            else
                sleep 0.2
            fi
            val=$(cat "$__shared__" 2>/dev/null)
        done
    }&)
    ({ # push values (could be in foreground if an explicit call to the function with "&" is desired)
        trap 'rm -f "$__shared__"' EXIT
        while true; do
            kill -s 0 $$ || exit # TODO: close zenity
            echo "$__val__" > "$__shared__"
            read -r __val__ || exit
        done < <(
            zenity --scale --print-partial --text="$1=" --title="Interactive variable modifier" \
            --value="$__val__" --min-value="$__min__" --max-value="$__max__" --step="$__step__" 2>/dev/null || {
                [[ $? != 1 ]] && echo "${FUNCNAME[0]} : zenity cannot be launched"
            } >&2
        )
    }&)
}


# ++ VAR [MIN] [MAX]
function ++ {
    echo dummy | read -r "$1" 2>/dev/null || {
        echo "${FUNCNAME[0]} : invalid identifier ‘$1’"; return 1
    } >&2
    local __max__=""
    local __min__=""
    local __val__
    if [ $# -ge 2 ]; then
        __max__=${2}
        __min__=${3-0}
        [ "$__max__" -eq "$__max__" ] 2>/dev/null || {
            echo "${FUNCNAME[0]} : invalid integer expression ‘$__max__’"; return 1
        } >&2
        [ "$__min__" -eq "$__min__" ] 2>/dev/null || {
            echo "${FUNCNAME[0]} : invalid integer expression ‘$__min__’"; return 1
        } >&2
        [ $# -le 3 ] || {
            echo "${FUNCNAME[0]} : too many arguments"; return 1
        } >&2
        if [ "$__min__" -gt "$__max__" ]; then
            __val__="$__min__"
            __min__="$__max__"
            __max__="$__val__"
        fi
        __val__=${!1-$__max__} # default will be incremented to $__min__
    else
        __val__=${!1}
    fi
    [ "$__val__" -eq "$__val__" ] 2>/dev/null || {
        echo "${FUNCNAME[0]} : \$$1 is NaN"; return 2
    } >&2
    ((__val__+=1))
    if [ -n "$__max__" ]; then
        if [ "$__val__" -lt "$__min__" ] || [ "$__val__" -gt "$__max__" ]; then
            eval "$1=$__min__"
            return 255
        fi
    fi
    eval "$1=$__val__"
    return 0
}


# -- VAR [MIN] [MAX]
function -- {
    echo dummy | read -r "$1" 2>/dev/null || {
        echo "${FUNCNAME[0]} : invalid identifier ‘$1’"; return 1
    } >&2
    local __max__=""
    local __min__=""
    local __val__
    if [ $# -ge 2 ]; then
        __max__=${2}
        __min__=${3-0}
        [ "$__max__" -eq "$__max__" ] 2>/dev/null || {
            echo "${FUNCNAME[0]} : invalid integer expression ‘$__max__’"; return 1
        } >&2
        [ "$__min__" -eq "$__min__" ] 2>/dev/null || {
            echo "${FUNCNAME[0]} : invalid integer expression ‘$__min__’"; return 1
        } >&2
        [ $# -le 3 ] || {
            echo "${FUNCNAME[0]} : too many arguments"; return 1
        } >&2
        if [ "$__min__" -gt "$__max__" ]; then
            __val__=$__min__
            __min__=$__max__
            __max__=$__val__
        fi
        __val__=${!1-$__min__} # default will be decremented to $__max__
    else
        __val__=${!1}
    fi
    [ "$__val__" -eq "$__val__" ] 2>/dev/null || {
        echo "${FUNCNAME[0]} : \$$1 is NaN"; return 2
    } >&2
    ((__val__-=1))
    if [ -n "$__max__" ]; then
        if [ "$__val__" -lt "$__min__" ] || [ "$__val__" -gt "$__max__" ]; then
            eval "$1=$__max__"
            return 255
        fi
    fi
    eval "$1=$__val__"
    return 0
}


# how [-p INDEX|-P|[COMMAND]...]
function how {
    local __STATUS__="$?" __PIPESTATUS__=("${PIPESTATUS[@]}")
    local -i __STATUS__; local -a __PIPESTATUS__
    local -i __EVAL__=0
    local __PIPEINDEX__=
    (($#)) && [ "${@: -1}" = "--" ] && __EVAL__=1
    if getopt --test > /dev/null; [[ $? -eq 4 ]]; then
        local __OPTS__
        __OPTS__="$(getopt --name "${FUNCNAME[0]}" \
            --options "+p:P" \
            --longoptions "pipe-status:,pipe-status-all" \
            -- "$@")" || return 1
        eval set -- "$__OPTS__"
    fi
    while [[ $# -ge 1 ]]; do # opts
        case "$1" in
        -p|--pipe-status ) shift
            [ "$1" != "@" ] && ! [ "$1" -eq "$1" ] 2>/dev/null && {
                echo "${FUNCNAME[0]} : invalid integer expression ‘$1’"; return 1
            } >&2
            __PIPEINDEX__="$1"; shift ;;
        -P|--pipe-status-all ) shift
            __PIPEINDEX__="@" ;;
        -- ) shift; break ;;
        * ) break ;;
        esac
    done
    if [ -n "$__PIPEINDEX__" ]; then
        __EVAL__=0
    else
        (($#)) && __EVAL__=1
    fi
    if ((__EVAL__)); then
        (exit $__STATUS__)
        eval -- "$@"
        __STATUS__=$? __PIPESTATUS__=("${PIPESTATUS[@]}")
    elif (($#)); then
        echo "${FUNCNAME[0]} : too many arguments (mode pipe-status)" >&2;
        return 1
    fi

    if [ "$__PIPEINDEX__" = "@" ]; then
        __PIPESTATUS__=("${__PIPESTATUS__[@]}")
    elif [ -n "$__PIPEINDEX__" ]; then
        __PIPESTATUS__=("${__PIPESTATUS__[@]: $__PIPEINDEX__:1}")
    else
        __PIPESTATUS__=("$__STATUS__")
    fi
    local -i __S__
    __STATUS__=0
    for __S__ in "${__PIPESTATUS__[@]}"; do
        ((__S__)) && __STATUS__=$__S__ && break
    done
    {
        case $__STATUS__ in
            0 ) echo -en "\e[01;42m SUCCESS \e[m" ;;
            * ) echo -en "\e[01;41m FAILURE \e[m"
                if ((${#__PIPESTATUS__[@]}>1)) || ((__STATUS__!=1)); then
                    echo -en " \e[01;30m(${__PIPESTATUS__[0]}"
                    for __S__ in "${__PIPESTATUS__[@]:1}"; do
                        echo -en "|$__S__"
                    done
                    echo -en ")\e[m"
                fi ;;
        esac
        echo
    }
    return "$__STATUS__"
}


# mmake [OPTION]... [TARGET]...
function mmake {
    local -r TARGET="$( (($#)) && printf " %q" "$@" )"
    mill -i \
        -F "[Mm]akefile" \
        -C "track -- [Mm]akefile \$($SNAIL_PATH/util/make_dependencies.sh$TARGET); make -q$TARGET 2>/dev/null; [ \$? -eq 1 ]" \
        -- "make$TARGET; how"
}


# shellcheck source=./boris.sh
. "$SNAIL_PATH/boris.sh"

# shellcheck source=./completion.sh
. "$SNAIL_PATH/completion.sh"

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap "clear" EXIT
    cd "$(dirname "$0")" || exit
    # shellcheck disable=SC2016
    mill -q -p 0.1 '
        ++ FRAME 1 || ++ X -19 $(tput cols)
        clear
        echo
        snail $FRAME $X
        echo
        echo ">>> source this script to load features"
    '
    # echo "source this script to load features" >&2 && exit 1
fi
