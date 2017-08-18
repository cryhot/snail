#!/usr/bin/env bash
# Copyright (c) 2017 Jean-Raphaël Gaglione


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
        echo "${FUNCNAME[0]} : invalid integer expression ‘$__min__’"; return 1
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
            echo "$__val__" >| "$__shared__"
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
