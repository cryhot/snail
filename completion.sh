#!/bin/bash
# Copyright (c) 2017 Jean-Raphaël Gaglione


# name of integer variable (by value)
function _intvar {
    local VAR
    COMPREPLY=()
    for VAR in $(compgen -v -- "${COMP_WORDS[COMP_CWORD]}"); do
        [ "${!VAR}" -eq "${!VAR}" ] 2>/dev/null || continue
        COMPREPLY+=("$VAR")
    done
}


# name of integer variable (by value or declaration)
function _intvar_abstract {
    local VAR
    COMPREPLY=($(compgen -W "$(
        declare -pi | awk '{print $3}' | awk -F "=" '{print $1}'
    )" -- "${COMP_WORDS[COMP_CWORD]}"))
    for VAR in $(compgen -v -- "${COMP_WORDS[COMP_CWORD]}"); do
        [ "${!VAR}" -eq "${!VAR}" ] 2>/dev/null || continue
        COMPREPLY+=("$VAR")
    done
}


# track completion
function _track {
    local -i i
    local arg=""
    local CUR
    for (( i=1; i <= COMP_CWORD; i++ )); do
        case "$arg" in
        esac
        [ -n "$arg" ] && arg="" && continue
        CUR="${COMP_WORDS[i]}"
        case "$CUR" in
        --* )
            if ((i < COMP_CWORD)); then
                case "$CUR" in
                -- ) _minimal; return ;;
                --timeout ) arg="t" ;;
                --delay )   arg="T" ;;
                esac
            else
                COMPREPLY=($(compgen -W "
                    --or
                    --and
                    --glob
                    --wildcard
                    --timeout
                    --delay
                " -- "$CUR"))
            fi ;;
        -*[tT] ) arg="${CUR: -1}" ;;
        -* ) ;;
        * ) _minimal; return ;;
        esac
    done
}


# mill completion
function _mill {
    local -i i
    local arg=""
    local CUR
    for (( i=1; i <= COMP_CWORD; i++ )); do
        case "$arg" in
        F ) ((i == COMP_CWORD)) && _minimal ;;
        esac
        [ -n "$arg" ] && arg="" && continue
        CUR="${COMP_WORDS[i]}"
        case "$CUR" in
        --* )
            if ((i < COMP_CWORD)); then
                case "$CUR" in
                -- ) _command_offset $((i+1)); return ;;
                --period )     arg="p" ;;
                --timeout )    arg="T" ;;
                --track-file ) arg="F" ;;
                --condition )  arg="C" ;;
                esac
            else
                COMPREPLY=($(compgen -W "
                    --period
                    --instant
                    --timeout
                    --track-file
                    --condition
                    --quiet
                    --unbuffered
                    --buffered
                " -- "$CUR"))
            fi ;;
        -*[pTFC] ) arg="${CUR: -1}" ;;
        -* ) ;;
        * ) _command_offset $i; return ;;
        esac
    done
}


# scale completion
function _scale {
    ((COMP_CWORD == 1)) && _intvar_abstract
}


# ++ and -- completion
function _increment {
    ((COMP_CWORD == 1)) && _intvar
}

# mmake completion
function _mmake {
    local OK_MAKE=0
    [ -e "/usr/share/bash-completion/completions/make" ] && OK_MAKE=1 &&
        source "/usr/share/bash-completion/completions/make"
    local -i i
    local arg=""
    local CUR
    for (( i=1; i <= COMP_CWORD; i++ )); do
        case "$arg" in
        esac
        [ -n "$arg" ] && arg="" && continue
        CUR="${COMP_WORDS[i]}"
        case "$CUR" in
        --* )
            if ((i < COMP_CWORD)); then
                case "$CUR" in
                -- ) ((OK_MAKE)) && _make; return ;; #FIXME make options not working
                --period ) arg="p" ;;
                esac
            else
                COMPREPLY=()
                ((OK_MAKE)) && _make #FIXME does nothing
                COMPREPLY+=($(compgen -W "
                    --period
                " -- "$CUR"))
            fi ;;
        -*[p] ) arg="${CUR: -1}" ;;
        -* ) ((COMP_CWORD == 1)) && ((OK_MAKE)) && _make ;;
        * ) ((OK_MAKE)) && _make; return ;;
        esac
    done
}


complete -F _track track
complete -F _mill mill
complete -F _scale scale
complete -F _increment -- ++
complete -F _increment -- --
complete -F _mmake mmake
