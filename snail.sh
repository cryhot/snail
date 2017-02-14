#!/bin/bash
# Copyright (c) 2017 Jean-Raphaël Gaglione
[[ "$_" == "$0" ]] && echo "source this script to load features" >&2 && exit 1

# track FILE [...]
function track {
    local -i and=0
    while [[ $# -ge 1 ]]; do # opts
        case "$1" in
        -o|--or ) shift; and=0 ;;
        -a|--and ) shift; and=1 ;;
        *) break ;;
        esac
    done
    local -A modif
    local file
    for file in "$@"; do
        modif[$file]=$(date -r "$file" +%s 2>/dev/null) || {
            echo "cannot track ‘$file’" >&2 ; return 1
        }
    done
    local -i count
    while true; do
        count=0
        for file in "${!modif[@]}"; do
            if [ "$(date -r "$file" +%s 2>/dev/null)" -ne "${modif[$file]}" ]; then
                ((and)) && unset modif[$file] || return
            else
                count+=1
            fi
        done
        ((count)) || return
        sleep 0.2
    done
}

# mill [-p PERIOD] COMMAND
function mill {
    local __period__="0.2"
    while [[ $# -ge 1 ]]; do # opts
        case "$1" in
        -p|--period ) shift
            __period__="$1"; shift
            [[ "$__period__" =~ ^[+]?([0-9]*[.]?[0-9]+|[0-9]+[.])([eE][-+]?[0-9]+)?$ ]] || {
                echo "invalid time interval ‘$__period__’" >&2; return 1
            } ;;
        * ) break ;;
        esac
    done
    local __cwd__
    local -r __buffer__="/dev/shm/mill-$$-$RANDOM"
    while true; do
        __cwd__="$(pwd)"
        [ "$__cwd__" = "$HOME" ] && __cwd__="~" || __cwd__=$(basename $__cwd__)
        # echo -ne "\033[01;31mmill\033[00m:\033[01;34m${__cwd__}\033[00m$ "
        echo -ne "\033[01;38;5;202mmill\033[00m:\033[01;34m${__cwd__}\033[00m$ " > "$__buffer__"
        echo "$@" >> "$__buffer__"
        eval -- "$@" >> "$__buffer__" 2>&1 # TODO: try a PTY
        clear
        cat "$__buffer__"
        sleep "$__period__"
    done
}

# scale VAR [MIN] [MAX]
function scale {
    echo dummy | read -r "$1" 2>/dev/null || {
        echo "invalid identifier ‘$1’" >&2; return 1
    }
    local __val__=(/dev/shm/scale-$$-$1-*)
    [ ${#__val__[@]} -ge 4 ] && echo "too many open scales for ‘$1’" >&2 && return 3
    local __val__=(/dev/shm/scale-$$-*)
    [ ${#__val__[@]} -ge 16 ] && echo "too many open scales for this terminal" >&2 && return 3
    local -r __shared__="/dev/shm/scale-$$-$1-$RANDOM"
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
            __val__=$__min__
        fi
    fi
    eval "$1=$__val__"
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
            __val__=$__max__
        fi
    fi
    eval "$1=$__val__"
}
