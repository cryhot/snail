#!/usr/bin/env bash

# Set SNAIL_PATH as the directory containing this file.
# This variable is necessary for some features : do not comment these lines.
# SNAIL_PATH is made readonly.
if [ -n "${SNAIL_PATH+_}" ]; then
    [ "$SNAIL_PATH" != "$(dirname "${BASH_SOURCE[0]}")" ] && {
        echo "SNAIL_PATH already defined"
        [[ "${BASH_SOURCE[0]}" == "$0" ]] && return 1 || exit 1
    } >&2
else
    SNAIL_PATH="$(dirname "${BASH_SOURCE[0]}")"
    declare -r SNAIL_PATH
fi

# Remove the files generated during this session.
[[ "${BASH_SOURCE[0]}" == "$0" ]] || {
    nohup "$SNAIL_PATH/clean.sh" --wait $$ &>/dev/null &
}


# Uncomment the mill prompt string wanted, or override it later.
{
    # 256 color
    MPS1=${MPS1-'\[\e[01;38;5;202m\]mill\[\e[m\]:\[\e[01;34m\]\W\[\e[m\]\$ '}
    MPS2=${MPS2-'\[\e[01;38;5;202m\]>\[\e[m\] '}

    # 8 color
    # MPS1=${MPS1-'\[\e[01;31m\]mill\[\e[m\]:\[\e[01;34m\]\W\[\e[m\]\$ '}
    # MPS2=${MPS2-'\[\e[01;31m\]>\[\e[m\] '}

    # no color
    # MPS1=${MPS1-'\[\e[01m\]mill\[\e[m\]:\[\e[01m\]\W\[\e[m\]\$ '}
    # MPS2=${MPS2-'\[\e[01m\]>\[\e[m\] '}

    # ASCII
    # MPS1=${MPS1-'mill:\W\$ '}
    # MPS2=${MPS2-'> '}
}


# ===== FEATURES ===== #

# main module (mill track scale ++ -- how mmake openfd closefd)
# shellcheck source=./boris.sh
source "$SNAIL_PATH/snail.sh"

# easter-egg (snail)
# shellcheck source=./boris.sh
source "$SNAIL_PATH/boris.sh"


# ===== OTHER ===== #

# defines command line completion
# shellcheck source=./completion.sh
source "$SNAIL_PATH/completion.sh"


# ===== DEMO ===== #

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
