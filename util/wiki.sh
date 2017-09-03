#!/usr/bin/env bash
# Copyright (c) 2017 Jean-Raphaël Gaglione

if [ -f "$SNAIL_PATH/wiki/$1" ]; then
    if command -v pandoc && command -v lynx &>/dev/null; then
        pandoc "$SNAIL_PATH/wiki/$1" | lynx -stdin
    elif command -v mdless &>/dev/null; then
        mdless "$SNAIL_PATH/wiki/$1"
    else
        less "$SNAIL_PATH/wiki/$1"
    fi
else
    PAGE="${1##*/}"
    PAGE="${PAGE%.*}"
    echo "checkout the online documentation :"
    echo "    https://github.com/cryhot/snail/wiki/$PAGE"
fi
