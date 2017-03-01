#!/bin/bash
# Copyright (c) 2017 Jean-Raphaël Gaglione

# track [-t|-T TIMEOUT] [-o|-a] [-g|-w] FILE...
function track {
    local -i and=0
    local -i glob=0
    local -i delay=-1
    local timeout=""
    while [[ $# -ge 1 ]]; do # opts
        case "$1" in
        -o|--or ) shift; and=0 ;;
        -a|--and ) shift; and=1 ;;
        -g|--glob ) shift; glob=1 ;;
        -w|--wildcard ) shift; glob=1 ;;
        -t|--timeout ) shift
            [ "$1" -ge "0" ] 2>/dev/null || {
                echo "invalid positive integer expression ‘$1’" >&2; return 1
            }
            timeout="$1"; shift ;;
        -T|--delay ) shift
            [ "$1" -ge "0" ] 2>/dev/null || {
                echo "invalid positive integer expression ‘$1’" >&2; return 1
            }
            delay="$1"; shift ;;
        -- ) shift; break ;;
        * ) break ;;
        esac
    done
    local -a files
    local -A modif
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
        #     echo "cannot track ‘$file’" >&2 ; return 1
        # }
    done
    [ -n "$timeout" ] && ((timeout+=$(date +%s)))
    local list
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

# mill [-p PERIOD|-i] [-q|-b|-B] [-T TIMEOUT] [-C CONDITION] COMMAND...
function mill {
    local __period__ __mode__
    local __timeout__
    local __condition__="false"
    local -i __CONDS__=0
    while [[ $# -ge 1 ]]; do # opts
        case "$1" in
        -p|--period ) shift
            [[ "$1" =~ ^[+]?([0-9]*[.]?[0-9]+|[0-9]+[.])([eE][-+]?[0-9]+)?$ ]] || {
                echo "invalid time interval ‘$1’" >&2; return 1
            }
            __period__="$1"; shift ;;
        -i|--instant ) shift
            __period__=0 ;;
        -T|--timeout ) shift
            [ "$1" -ge "0" ] 2>/dev/null || {
                echo "invalid positive integer expression ‘$1’" >&2; return 1
            }
            __timeout__="$1"; shift; __CONDS__=1 ;;
        -C|--condition ) shift
            __condition__="$1"; shift; __CONDS__=1 ;;
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
    if ! ((__CONDS__)); then # no conditions
        __period__=${__period__-0.2}
        __timeout__=${__timeout__-0}
        __mode__=${__mode__-2}
    else # conditions specified
        __period__=${__period__-0}
        __mode__=${__mode__-1}
    fi
    local -r __buffer__="/dev/shm/mill-$$-$RANDOM$RANDOM"
    local -r __period__ __mode__ __timeout__ __condition__
    ((__mode__==2)) && ({ # cleaner
        while kill -s 0 $$; do
            sleep 9
        done
        rm "$__buffer__"
    }&) >/dev/null 2>&1
    local __cwd__ __first_line__ __line__ __time_out__
    while true; do
        [ -n "$__timeout__" ] && __time_out__=$(($(date +%s)+__timeout__))
        ((__mode__>0)) && {
            __cwd__="$(pwd)"
            [ "$__cwd__" = "$HOME" ] && __cwd__="~" || __cwd__=$(basename $__cwd__)
        }
        case $__mode__ in
        0 ) # QUIET
            eval -- "$@"
            ;;
        1 ) # UNBUFFERED
            clear
            __first_line__="yes"
            echo -ne "\033[01;38;5;202mmill\033[00m:\033[01;34m${__cwd__}\033[00m$ "
            while IFS='' read -r __line__; do
                [ -n "$__line__" ] || continue
                [ -n "$__first_line__" ] && __first_line__="" || echo -ne "> "
                echo "$__line__"
            done <<< "$@"
            eval -- "$@"
            ;;
        2 ) # BUFFERED
            {
                __first_line__="yes"
                echo -ne "\033[01;38;5;202mmill\033[00m:\033[01;34m${__cwd__}\033[00m$ "
                while IFS='' read -r __line__; do
                    [ -n "$__line__" ] || continue
                    [ -n "$__first_line__" ] && __first_line__="" || echo -ne "> "
                    echo "$__line__"
                done <<< "$@"
                eval -- "$@" 2>&1 # TODO: try a PTY
            } > "$__buffer__"
            clear
            cat "$__buffer__"
            rm "$__buffer__" # does not always works
            ;;
        esac
        while true; do
            sleep "$__period__"
            [ -n "$__timeout__" ] && (($(date +%s)>=__time_out__)) && break
            eval "$__condition__" && break
        done
    done
}
rm /dev/shm/mill-$$-* 2>/dev/null

# scale VAR [MIN] [MAX]
function scale {
    echo dummy | read -r "$1" 2>/dev/null || {
        echo "invalid identifier ‘$1’" >&2; return 1
    }
    local __val__=(/dev/shm/scale-$$-$1-*)
    [ ${#__val__[@]} -ge 4 ] && echo "too many open scales for ‘$1’" >&2 && return 3
    local __val__=(/dev/shm/scale-$$-*)
    [ ${#__val__[@]} -ge 16 ] && echo "too many open scales for this terminal" >&2 && return 3
    local -r __shared__="/dev/shm/scale-$$-$1-$RANDOM$RANDOM"
    local __prev__=${!1}
    local __min__=${2-0}
    local __max__=${3-100}
    local __step__=1
    [ "$__min__" -eq "$__min__" ] 2>/dev/null || {
        echo "invalid integer expression ‘$__min__" >&2; return 1
    }
    [ "$__max__" -eq "$__max__" ] 2>/dev/null || {
        echo "invalid integer expression ‘$__max__’" >&2; return 1
    }
    if [ "$__min__" -gt "$__max__" ]; then
        __val__="$__min__"
        __min__="$__max__"
        __max__="$__val__"
    fi
    [ "$__min__" -eq "$__max__" ] && echo "bounds must be different values" >&2 && return 1
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
        trap 'rm "$__shared__"' EXIT
        while [ -n "$__val__" ]; do
            kill -s 0 $$ || exit # TODO: close zenity
            echo "$__val__" > "$__shared__"
            read -r "__val__"
        done < <(zenity --scale --print-partial "--text=$1=" "--title=Interactive variable modifier" \
            "--value=$__val__" "--min-value=$__min__" "--max-value=$__max__" "--step=$__step__" 2>/dev/null || \
            ([[ $? != 1 ]] && echo "zenity cannot be launched") >&2)
    }&)
}
rm /dev/shm/scale-$$-* 2>/dev/null

# ++ VAR [MIN] [MAX]
function ++ {
    echo dummy | read -r "$1" 2>/dev/null || {
        echo "invalid identifier ‘$1’" >&2; return 1
    }
    local __max__=""
    local __min__=""
    local __val__
    if [ $# -ge 2 ]; then
        __max__=${2}
        __min__=${3-0}
        [ "$__max__" -eq "$__max__" ] 2>/dev/null || {
            echo "invalid integer expression ‘$__max__’" >&2; return 1
        }
        [ "$__min__" -eq "$__min__" ] 2>/dev/null || {
            echo "invalid integer expression ‘$__min__" >&2; return 1
        }
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
        echo "\$$1 is NaN" >&2; return 2
    }
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
        echo "invalid identifier ‘$1’" >&2; return 1
    }
    local __max__=""
    local __min__=""
    local __val__
    if [ $# -ge 2 ]; then
        __max__=${2}
        __min__=${3-0}
        [ "$__max__" -eq "$__max__" ] 2>/dev/null || {
            echo "invalid integer expression ‘$__max__’" >&2; return 1
        }
        [ "$__min__" -eq "$__min__" ] 2>/dev/null || {
            echo "invalid integer expression ‘$__min__" >&2; return 1
        }
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
        echo "\$$1 is NaN" >&2; return 2
    }
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

# mmake [-p PERIOD] [OPTION]... [TARGET]...
function mmake {
    local __period__
    while [[ $# -ge 1 ]]; do # opts
        case "$1" in
        -p|--period ) shift;
            __period__="$1"; shift ;;
        -- ) shift; break ;;
        * ) break ;;
        esac
    done
    mill -p "${__period__-0.2}" -- make "$@"
}

. "$(dirname "$BASH_SOURCE")/boris.sh"
if [[ "$BASH_SOURCE" == "$0" ]]; then
    trap "clear" EXIT
    cd "$(dirname "$0")"
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
