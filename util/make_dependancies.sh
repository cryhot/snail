#!/usr/bin/env bash
# make_dependancies.sh [TARGET]...
[[ "$BASH_SOURCE" == "$0" ]] || {
    echo "must not be sourced" >&2 && return 2
}

# get the makefile database
MDB="$(make -qp)"
declare -A DEP EXPLORE

# get initial targets
if (($#)); then
    for TARGET in "$@"; do
        EXPLORE["$TARGET"]=1
    done
else
    for TARGET in $(sed -n "/^.DEFAULT_GOAL[ :]*=/ p;" <<< "$MDB" | sed -e "s/^.DEFAULT_GOAL[ :]*=//g"); do
        EXPLORE["$TARGET"]=1
    done
fi

# explore recursively
while [ ${#EXPLORE[@]} -gt 0 ]; do
    for TARGET in "${!EXPLORE[@]}"; do break; done
    DEP["$TARGET"]=1
    unset EXPLORE["$TARGET"]
    for D in $(sed -n "/^${TARGET//\//\\\/}:/ p;" <<< "$MDB" | sed -e "s/^${TARGET//\//\\\/}://g"); do
        [ -n "${DEP["$D"]}" ] && continue
        EXPLORE["$D"]=1
    done
done

# print result
echo "${!DEP[@]}"
