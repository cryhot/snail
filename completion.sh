#!/usr/bin/env bash
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


# arbitrary integer value
function _numval {
    COMPREPLY+=("${COMP_WORDS[COMP_CWORD]}"{0..9})
    # TODO: -f: accept float
    # TODO: -n: accept negative numbers
    # TODO: do not complete when incorrect
}


# track completion
function _track {
    # shellcheck disable=SC2034
    if [ -z "$(declare -F _minimal 2>/dev/null)" ]; then
        [ -e "/usr/share/bash-completion/bash_completion" ] &&
            source "/usr/share/bash-completion/bash_completion"
    fi

    local -i i
    local arg=""
    local CUR
    for (( i=1; i <= COMP_CWORD; i++ )); do
        CUR="${COMP_WORDS[i]}"
        case "$arg" in
        t|T ) ((i == COMP_CWORD)) && _numval ;;
        esac
        if [ -n "$arg" ]; then
            arg=""
            ((i < COMP_CWORD)) && continue || return
        fi
        case "$CUR" in
        --* )
            if ((i < COMP_CWORD)); then
                case "$CUR" in
                -- ) i+=1; break ;;
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
        * ) break ;;
        esac
        ((i < COMP_CWORD)) || return
    done
    _minimal
}


# mill completion
function _mill {
    # shellcheck disable=SC2034
    if [ -z "$(declare -F _minimal 2>/dev/null)" ]; then
        [ -e "/usr/share/bash-completion/bash_completion" ] &&
            source "/usr/share/bash-completion/bash_completion"
    fi

    local -i i
    local arg=""
    local CUR
    for (( i=1; i <= COMP_CWORD; i++ )); do
        CUR="${COMP_WORDS[i]}"
        case "$arg" in
        p ) ((i == COMP_CWORD)) && _numval -f ;;
        T ) ((i == COMP_CWORD)) && _numval ;;
        F ) ((i == COMP_CWORD)) && _minimal ;;
        C ) ((i == COMP_CWORD)) && _command_offset $i ;;
        esac
        if [ -n "$arg" ]; then
            arg=""
            ((i < COMP_CWORD)) && continue || return
        fi
        case "$CUR" in
        --* )
            if ((i < COMP_CWORD)); then
                case "$CUR" in
                -- ) i+=1; break ;;
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
        * ) break ;;
        esac
        ((i < COMP_CWORD)) || return
    done
    _command_offset $i
}


# scale completion
function _scale {
    ((COMP_CWORD == 1)) && _intvar_abstract
    ((COMP_CWORD == 2)) && _numval -n
    ((COMP_CWORD == 3)) && _numval -n
}


# ++ and -- completion
function _increment {
    ((COMP_CWORD == 1)) && _intvar
    ((COMP_CWORD == 2)) && _numval -n
    ((COMP_CWORD == 3)) && _numval -n
}


# how completion
function _how {
    # shellcheck disable=SC2034
    if [ -z "$(declare -F _minimal 2>/dev/null)" ]; then
        [ -e "/usr/share/bash-completion/bash_completion" ] &&
            source "/usr/share/bash-completion/bash_completion"
    fi

    local -i i
    local arg=""
    local CUR
    local -i __eval__=1
    for (( i=1; i <= COMP_CWORD; i++ )); do
        CUR="${COMP_WORDS[i]}"
        case "$arg" in
        p ) ((i == COMP_CWORD)) && {
                [ "$2" != "@" ] && _numval -n
                COMPREPLY+=("$(compgen -W "@" -- "$CUR")")
            }
            __eval__=0;;
        esac
        if [ -n "$arg" ]; then
            arg=""
            ((i < COMP_CWORD)) && continue || return
        fi
        case "$CUR" in
        --* )
            if ((i < COMP_CWORD)); then
                case "$CUR" in
                -- ) i+=1; break ;;
                --pipe-status )     arg="p" ;;
                esac
            else
                COMPREPLY=($(compgen -W "
                    --pipe-status
                    --pipe-status-all
                " -- "$CUR"))
            fi ;;
        -*[p] ) arg="${CUR: -1}" ;;
        -* ) ;;
        * ) break ;;
        esac
        ((i < COMP_CWORD)) || return
    done
    ((__eval__)) && _command_offset $i
}


# mmake completion
function _mmake {
    local OK_MAKE=1
    # shellcheck disable=SC2034
    if [ -z "$(declare -F _make 2>/dev/null)" ]; then
        [ -e "/usr/share/bash-completion/completions/make" ] &&
            source "/usr/share/bash-completion/completions/make" ||
            OK_MAKE=0
    fi
    COMP_WORDS[0]="make"
    ((OK_MAKE)) && _make make "$2" "$3"
}


complete -F _track track
complete -F _mill mill
complete -F _scale scale
complete -F _increment -- ++
complete -F _increment -- --
complete -F _how how
complete -F _mmake mmake
