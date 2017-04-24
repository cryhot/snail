#!/usr/bin/env bash
# Copyright (c) 2017 Jean-Raphaël Gaglione

# snail [-a|[%]FRAME] [POSITION] [WIDTH]
function snail {
    local -i f
    if [ "${1::1}" == "%" ]; then
        [ -n "${1:1}" ] && f=${1:1} || f=1
        f="$(date +%s%N)*f/1000000000"
    elif [[ "$1" =~ ^(-a|--auto)$ ]]; then
        f=$((__snail_frame__+1))
    else f=${1-$((__snail_frame__+1))};fi
    local -i s=${2-0}
    local -i l=${3-$(tput cols)}
    local -i m=0
    local -i M=0
    ((s<0)) && m=$((1-s)) && s=0
    ((s<l)) && M=$((l-s)) || s=l
    local S
    S=$(yes " " | head -$s | tr -d "\n")
    f=f%2
    ((f<0)) && f=$((f+2))
    case $f in
    0 )
        echo -n "$S"; echo -n "     _____     | / "  | tail -c +$m | head -c $M ; echo
        echo -n "$S"; echo -n "   .' __  \`.   !/  " | tail -c +$m | head -c $M ; echo
        echo -n "$S"; echo -n "  / .'_ \   \ /  ; "  | tail -c +$m | head -c $M ; echo
        echo -n "$S"; echo -n "  \ \`._; ;--!' ,'  " | tail -c +$m | head -c $M ; echo
        echo -n "$S"; echo -n " ._>.___/     /    "  | tail -c +$m | head -c $M ; echo
        echo -n "$S"; echo -n " \`-.________,'     " | tail -c +$m | head -c $M ; echo
        ;;
    1 )
        echo -n "$S"; echo -n "     _____      | /"  | tail -c +$m | head -c $M ; echo
        echo -n "$S"; echo -n "   .' __  \`.    !/ " | tail -c +$m | head -c $M ; echo
        echo -n "$S"; echo -n "  / .'_ \   \ ,'  ;"  | tail -c +$m | head -c $M ; echo
        echo -n "$S"; echo -n "  \ \`._; ;--!'  ,' " | tail -c +$m | head -c $M ; echo
        echo -n "$S"; echo -n ".-.>.___/     ,'   "  | tail -c +$m | head -c $M ; echo
        echo -n "$S"; echo -n " \`._________,'     " | tail -c +$m | head -c $M ; echo
        ;;
    esac
    export __snail_frame__=$f
}

if [[ "$BASH_SOURCE" == "$0" ]]; then # called
    snail "$@"
fi
