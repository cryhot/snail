#!/bin/bash
# Copyright (c) 2017 Jean-Raphaël Gaglione
[[ "$_" == "$0" ]] && echo "source this script to load features" >&2 && exit 1

# mill [-p PERIOD] COMMAND
function mill {
    local __period__="0.2"
    while [[ $# -gt 1 ]]; do
        local arg="$1"
        case "$arg" in
        -p|--period)
            __period__="$2"; shift
            [[ "$__period__" =~ ^[+]?([0-9]*[.]?[0-9]+|[0-9]+[.])([eE][-+]?[0-9]+)?$ ]] || {
                echo "invalid time interval ‘$__period__’" >&2; return 1
            } ;;
        *)
            break ;;
        esac
        shift
    done
    local __cwd__
    while :; do
        clear
        __cwd__="$(pwd)"
        [ "$__cwd__" = "$HOME" ] && __cwd__="~" || __cwd__=$(basename $__cwd__)
        # echo -ne "\033[01;31mmill\033[00m:\033[01;34m${__cwd__}\033[00m$ "
        echo -ne "\033[01;38;5;202mmill\033[00m:\033[01;34m${__cwd__}\033[00m$ "
        echo "$@"
        eval "$@"
        sleep "$__period__"
    done
}

# scale VAR [MIN] [MAX]
function scale {
    echo dummy | read -r "$1" 2>/dev/null || {
        echo "invalid identifier ‘$1’" >&2; return 1
    }
    local __prev__=${!1}
    local __min__=${2-0}
    local __max__=${3-100}
    local __val__
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
    local __shared__="/dev/shm/scale-$$-$1-$RANDOM"
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
        while [ -n "$__val__" ]; do
            echo "$__val__" > "$__shared__"
            read -r "__val__"
        done < <(zenity --scale --print-partial "--text=$1=" "--title=Interactive variable modifier" \
            "--value=$__val__" "--min-value=$__min__" "--max-value=$__max__" "--step=$__step__" 2>/dev/null || \
            ([[ $? != 1 ]] && echo "zenity cannot be launched") >&2)
        rm "$__shared__"
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
        __val__=${!1-$((__min__-1))}
    else
        __val__=${!1}
    fi
    [ "$__val__" -eq "$__val__" ] 2>/dev/null || {
        echo "\$$1 is NaN" >&2; return 2
    }
    __val__=$((__val__+1))
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
            __val__="$__min__"
            __min__="$__max__"
            __max__="$__val__"
        fi
        __val__=${!1-$((__max__+1))}
    else
        __val__=${!1}
    fi
    [ "$__val__" -eq "$__val__" ] 2>/dev/null || {
        echo "\$$1 is NaN" >&2; return 2
    }
    __val__=$((__val__-1))
    if [ -n "$__max__" ]; then
        if [ "$__val__" -lt "$__min__" ] || [ "$__val__" -gt "$__max__" ]; then
            __val__=$__max__
        fi
    fi
    eval "$1=$__val__"
}
