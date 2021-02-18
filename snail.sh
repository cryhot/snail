#!/usr/bin/env bash
# Copyright (c) 2017 Jean-Raphaël Gaglione


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
            --longoptions "or,and,glob,wildcard,timeout:,delay:,help" \
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
        --help ) shift
            "$SNAIL_PATH/util/wiki.sh" "man/man-track.md"; return 0;;
        -- ) shift; break ;;
        * ) break ;;
        esac
    done
    if [[ $# -lt 1 ]]; then
        set -- "*"
        glob=1
    fi
    local -a files
    local -A modif
    # RECORD INFOS
    if ((glob)); then
        # shellcheck disable=SC2068,SC2048,SC2086
        mapfile -d '' files < <(shopt -s nullglob; IFS=""; (($#)) && printf "%s\0" $@)
    else
        files=("$@")
    fi
    for file in "${files[@]}"; do
        [ -z "$file" ] && continue
        modif[$file]=$(stat -c "%Z" "$file" 2>/dev/null) # || {
        #     echo "${FUNCNAME[0]} : cannot track ‘$file’"; return 1
        # } >&2
    done
    [ -n "$timeout" ] && ((timeout+=$(date +%s)))
    local -a list
    # TRACK CHANGES
    ((delay>=0)) && sleep "$delay" && timeout=${timeout:-0}
    local -i count
    while true; do
        count=0
        for file in "${!modif[@]}"; do
            if ! [ "$(stat -c "%Z" "$file" 2>/dev/null)" = "${modif[$file]}" ] 2>/dev/null; then
                ((and)) && unset modif["$file"] || return 0
            else
                count+=1
            fi
        done
        ((and && count==0)) && return 0
        if ((glob && ! and)); then
            # shellcheck disable=SC2068,SC2048,SC2086
            mapfile -d '' list < <(shopt -s nullglob; IFS=""; printf "%s\0" $@)
            [ ${#list[@]} -eq ${#files[@]} ] || return 0
            for file in "${!files[@]}"; do
                [ "${list[$file]}" = "${files[$file]}" ] || return 0
            done
        fi
        [ -n "$timeout" ] && (($(date +%s)>=timeout)) && return 255
        sleep 0.2
    done
}


# mill [-p PERIOD|-i] [-q|-b|-B] [-M] [-T TIMEOUT] [-F FILE] [-G] [-C CONDITION] COMMAND...
function mill {
    local __STATUS__=0
    local __period__ __mode__
    local __timeout__
    local -i __manual__=0
    local -a __tracked_files__=()
    local -i __track_command_files__=0
    local -a __conditions__=()
    local -i __CONDS__=0
    if getopt --test > /dev/null; [[ $? -eq 4 ]]; then
        local __OPTS__
        __OPTS__="$(getopt --name "${FUNCNAME[0]}" \
            --options "+p:iMT:F:GC:qbB" \
            --longoptions "period:,instant,manual,timeout:,track-file:,--track-command-files,condition:,quiet,unbuffered,buffered,help" \
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
        -M|--manual ) shift; ((__CONDS__|=1))
            __manual__=1 ;;
        -T|--timeout ) shift; ((__CONDS__|=2))
            [ "$1" -ge "0" ] 2>/dev/null || {
                echo "${FUNCNAME[0]} : invalid positive integer expression ‘$1’"; return 1
            } >&2
            __timeout__="$1"; shift ;;
        #-V|--track-var ) shift; ((__CONDS__|=4))
        -F|--track-file ) shift; ((__CONDS__|=8))
            # shellcheck disable=SC2068,SC2048,SC2086
            mapfile -d '' -O "${#__tracked_files__[@]}" __tracked_files__ < <(set -f; IFS="|"; printf "%s\0" $1); shift ;;
        -G|--track-command-files ) shift;
            __track_command_files__=1 ;;
        -C|--condition ) shift; ((__CONDS__|=16))
            __conditions__+=("$1"); shift ;;
        -q|--quiet ) shift
            __mode__=0 ;;
        -b|--unbuffered ) shift
            __mode__=1 ;;
        -B|--buffered ) shift
            __mode__=2 ;;
        --help ) shift
            "$SNAIL_PATH/util/wiki.sh" "man/man-mill.md"; return 0;;
        -- ) shift; break ;;
        * ) break ;;
        esac
    done
    if ((__track_command_files__)); then
        ((__CONDS__|=8))
        # shellcheck disable=SC2068,SC2048,SC2086
        mapfile -d '' -O "${#__tracked_files__[@]}" __tracked_files__ < <(set -f; IFS=$' \t\n;|&$()<>'; (($#)) && printf "%s\0" $@)
    fi
    __period__=${__period__-0.2}
    [ -t 1 ] || __mode__=${__mode__-0} # non interactive
    if ! ((__CONDS__)); then # no conditions
        __mode__=${__mode__-2}
    else # conditions specified
        __mode__=${__mode__-1}
    fi
    local -r __period__ __mode__
    local -r __CONDS__ __timeout__ __tracked_files__ __conditions__
    local __ps1__ __ps2__ __first_line__ __line__ __time_out__
    local __file__ __condition__ # iterators
    local -i __BREAK__
    local -a __files__ __files2__
    local -A __file_modif__
    # DEFINE IO
    case $__mode__ in
    0 ) # QUIET
        exec 513>&1 514>&2 ;;
    1 ) # UNBUFFERED
        exec 513>&1 514>&2 ;;
    2 ) # BUFFERED
        # TODO: try a PTY
        local __buffer__
        __buffer__=$(mktemp "/dev/shm/mill-$$-XXXXXXXX")
        exec 512<"$__buffer__"
        exec 513>"$__buffer__" 514>&513
        rm -f "$__buffer__"; unset __buffer__
        if ! { [ -x "$SNAIL_PATH/util/rewindfd" ] && [ -x "$SNAIL_PATH/util/seekfd" ]; } then
            notify-send --urgency=critical --icon=face-uncertain \
                "Hey! Snail is missing some files" \
                "You should run the following command, or expect some memory leaks...\n\$ make -C $SNAIL_PATH"
        fi &>/dev/null ;;
    esac
    # CYCLE
    while true; do
        # RECORD CONDITIONS INFOS
        # record `-T`
        [ -n "$__timeout__" ] && __time_out__=$(($(date +%s)+__timeout__))
        # record `-F`
        __file_modif__=()
        # shellcheck disable=SC2068,SC2048,SC2086
        mapfile -d '' __files__ < <(shopt -s nullglob; IFS=""; ((${#__tracked_files__[@]})) && printf "%s\0" ${__tracked_files__[@]})
        for __file__ in "${__files__[@]}"; do
            [ -z "$__file__" ] && continue
            __file_modif__[$__file__]=$(stat -c "%Z" "$__file__" 2>/dev/null)
        done
        # EXECUTE COMMAND
        {
            if ((__mode__!=0)); then # NOT QUIET
                ((__mode__==1)) && clear # UNBUFFERED
                __ps1__=$(PS1="$MPS1" "$BASH" --norc -i </dev/null 2>&1 | sed -n 's/^\(.*\)exit$/\1/p;')
                __ps2__=$(PS1="$MPS2" "$BASH" --norc -i </dev/null 2>&1 | sed -n 's/^\(.*\)exit$/\1/p;')
                echo -n "$__ps1__" && unset __first_line__
                while IFS='' read -r __line__; do
                    [ -n "$__line__" ] || continue
                    [ -z "$__first_line__" ] && __first_line__="no" || echo -n "$__ps2__"
                    echo "$__line__"
                done <<< "$@"
                [ -z "$__first_line__" ] && echo
            fi
            while read -t 0 -r; do read -r; done
            for __BREAK__ in 1 0; do
                ((__BREAK__)) || break
                (exit "$__STATUS__"); eval -- "$@"; __STATUS__="$?"
            done
        } 1>&513 2>&514 512<&- 513>&- 514>&-
        if ((__mode__==2)); then # BUFFERED
            clear
            cat <&512
            "$SNAIL_PATH/util/rewindfd" 513 2>/dev/null &&
            "$SNAIL_PATH/util/seekfd" 512 2>/dev/null
        fi
        ((__BREAK__)) && break;
        # LATENCY STAGE
        while read -t 0 -r; do read -r; done
        if [ $__mode__ != 0 ]; then
            ((__manual__)) && echo -ne "\e[01;38;5;202m[PRESS ENTER]\e[m"
        fi
        if ((__CONDS__==1)); then
            read -r && echo -en "\e[1A\e[2K"
        else while true; do
            # test `-T`
            [ -n "$__timeout__" ] && (($(date +%s)>=__time_out__)) && break
            # test `-F`
            for __file__ in "${!__file_modif__[@]}"; do
                [ "$(stat -c "%Z" "$__file__" 2>/dev/null)" = "${__file_modif__[$__file__]}" ] 2>/dev/null ||
                    break 2
            done
            # shellcheck disable=SC2068,SC2048,SC2086
            mapfile -d '' __files2__ < <(shopt -s nullglob; IFS=""; ((${#__tracked_files__[@]})) && printf "%s\0" ${__tracked_files__[@]})
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
            if ((__manual__)); then
                if read -t "$__period__" -r </dev/null; then
                    read -t 0 -r && read -r
                else
                    read -t "$__period__" -r
                    [ $? -lt 128 ]
                fi && echo -en "\e[1A\e[2K" && break
            else
                sleep "$__period__"
            fi
            ((__CONDS__)) || break
        done fi 512<&- 513>&- 514>&-
        # END OF CYCLE
    done
    exec 512<&- 513>&- 514>&-
} 512<&- 513>&- 514>&-


# how [-p INDEX|-P|[COMMAND]...]
function how {
    local __STATUS__="$?" __PIPESTATUS__=("${PIPESTATUS[@]}")
    local -i __STATUS__; local -a __PIPESTATUS__
    local -i __EVAL__=0
    local __PIPEINDEX__=
    (($#)) && [ "${*: -1}" = "--" ] && __EVAL__=1
    if getopt --test > /dev/null; [[ $? -eq 4 ]]; then
        local __OPTS__
        __OPTS__="$(getopt --name "${FUNCNAME[0]}" \
            --options "+p:P" \
            --longoptions "pipe-status:,pipe-status-all,help" \
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
        --help ) shift
            "$SNAIL_PATH/util/wiki.sh" "man/man-how.md"; return 0;;
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
