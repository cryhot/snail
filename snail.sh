
# mill [-p PERIOD] COMMAND
function mill() {
    local period="0.2"
    while [[ $# -gt 1 ]]; do
        local arg="$1"
        case "$arg" in
            -p|--period) period="$2"; shift ;;
            *) break ;;
        esac
        shift
    done
    while :; do
        clear
        echo -ne "\033[01;31mmill\033[00m:\033[01;34m$(pwd)\033[00m$ "
        echo "$@"
        eval $@
        sleep "$period"
    done
}

# scale VAR [MIN] [MAX]
function scale() {
    echo dummy | read "$1" 2>/dev/null || {
        echo "not a valid identifier" >&2; return 1
    }
    local __prev__=${!1}
    local __min__=${2-0}
    local __max__=${3-100}
    local __val__=$__min__
    [ "$__prev__" -eq "$__prev__" ] 2>/dev/null && __val__=$__prev__
    [ "$__val__" -lt "$__min__" ] && __val__=$__min__
    [ "$__val__" -gt "$__max__" ] && __val__=$__max__
    local __shared__="/dev/shm/scale-$$-$1-$RANDOM"
    echo "$__val__" > "$__shared__"
    ({ # pull values while file exists
        local oldval="not $__val__"
        while [ -n "$__val__" ]; do
            if [ "$__val__" != "$oldval" ]; then
                gdb --batch-silent -p "$$" \
                    -ex "set bind_variable(\"$1\", \"$__val__\", 0)" \
                    2>/dev/null # thanks BeniBela
                oldval="$__val__"
            else
                sleep 0.2
            fi
            __val__=$(cat "$__shared__" 2>/dev/null)
        done
    }&)
    ({ # push values
    while [ -n "$__val__" ]; do
        echo "$__val__" > "$__shared__"
        read "__val__"
    done < <(zenity --scale --print-partial "--text=$1=" "--title=Interactive variable modifier" \
        --value=$__val__ --min-value=$__min__ --max-value=$__max__ 2>/dev/null)
    rm "$__shared__"
    }&)
}

# ++ VAR
function ++ {
    echo dummy | read "$1" || {
        echo "not a valid identifier" >&2; return 1
    }
    [ "${!1}" -eq "${!1}" ] 2>/dev/null || { # is number
        echo "\$$1 is NaN" >&2; return 2
    }
    eval $1=$(($1+1))
}

# -- VAR
function -- {
    echo dummy | read "$1" || {
        echo "not a valid identifier" >&2; return 1
    }
    [ "${!1}" -eq "${!1}" ] 2>/dev/null || { # is number
        echo "\$$1 is NaN" >&2; return 2
    }
    eval $1=$(($1-1))
}
