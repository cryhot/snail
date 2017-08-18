#!/usr/bin/env bash
# Copyright (c) 2017 Jean-Raphaël Gaglione


# openfd FD
function openfd {
    { [ "$1" -ge "0" ] && [ "$1" -lt "1024" ]; } 2>/dev/null || {
        echo "${FUNCNAME[0]} : invalid file descriptor ‘$1’"; return 1
    } >&2
    eval "command >&$1" 2>/dev/null && {
        echo "${FUNCNAME[0]} : file descriptor ‘$1’ already opened"; return 2
    } >&2
    local PIPE
    PIPE=$(mktemp -u)
    mkfifo "$PIPE"
    eval "exec $1<>$PIPE"
    rm "$PIPE"
}

# closefd FD
function closefd {
    { [ "$1" -ge "0" ] && [ "$1" -lt "1024" ]; } 2>/dev/null || {
        echo "${FUNCNAME[0]} : invalid file descriptor ‘$1’"; return 1
    } >&2
    eval "exec $1>&-"
}

# seekfd FD [OFFSET] [WHENCE]
function seekfd {
    local -a ARGS=("$@")
    if [ $# -ge 3 ]; then
        case "${ARGS[3]}" in
        0|SET|SEEK_SET|START)  ARGS[3]=0;;
        1|CUR|SEEK_CUR|CURSOR) ARGS[3]=1;;
        2|END|SEEK_END)        ARGS[3]=2;;
        *) echo "${FUNCNAME[0]} : ‘${ARGS[3]}’ : bad whence" >&2; return 1;;
        esac
    fi
    # set -- "${ARGS[@]}"
    "$SNAIL_PATH/util/seekfd" "${ARGS[@]}"
}

# rewindfd FD [OFFSET]
function rewindfd {
    local -a ARGS=("$@")
    # set -- "${ARGS[@]}"
    "$SNAIL_PATH/util/rewindfd" "${ARGS[@]}"
}
