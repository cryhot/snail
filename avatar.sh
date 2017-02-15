#!/bin/bash
# Copyright (c) 2017 Jean-Raphaël Gaglione

# snail [FRAME] [POSITION] [WIDTH]
function snail {
    local -i s=${2-0}
    local -i l=${3-$(tput cols)}
    local -i m=0
    local -i M=0
    ((s<0)) && m=1-s && s=0
    ((s<l)) && M=l-s || s=l
    local S=`yes " " | head -$s | tr -d "\n"`
    case $((${1-0}%2)) in
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
}

if [[ "$BASH_SOURCE" == "$0" ]]; then # called
    snail "$@"
fi
