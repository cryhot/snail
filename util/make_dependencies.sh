#!/usr/bin/env bash
# make_dependencies.sh [TARGET]...
[[ "${BASH_SOURCE[0]}" == "$0" ]] || {
    echo "must not be sourced" >&2 && return 2
}

# get the makefile database
MDB="$(make -qp "$@" 2>/dev/null)"
declare -A DEP EXPLORE

# get initial targets
for TARGET in "$@"; do
    [[ "$TARGET" =~ ^-.*$ ]] && continue
    EXPLORE["$TARGET"]=1
done
if [ ${#EXPLORE[@]} -eq 0 ]; then
    # shellcheck disable=SC2013
    for TARGET in $(sed -n "/^.DEFAULT_GOAL[ :]*=/ p;" <<< "$MDB" | sed -e "s/^.DEFAULT_GOAL[ :]*=//g"); do
        EXPLORE["$TARGET"]=1
    done
fi

# explore recursively
while [ ${#EXPLORE[@]} -gt 0 ]; do
    for TARGET in "${!EXPLORE[@]}"; do break; done
    DEP["$TARGET"]=1
    unset EXPLORE["$TARGET"]
    # shellcheck disable=SC2013
    for D in $(sed -n "/^${TARGET//\//\\/}:/ p;" <<< "$MDB" | sed -e "s/^${TARGET//\//\\/}://g"); do
        [ -n "${DEP["$D"]}" ] && continue
        EXPLORE["$D"]=1
    done
done

# print result
echo "${!DEP[@]}"
