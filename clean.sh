#!/usr/bin/env bash
# clean.sh PID
[[ "${BASH_SOURCE[0]}" == "$0" ]] || {
    echo "must not be sourced" >&2 && return 2
}

__wait__=0

while [[ $# -ge 1 ]]; do # opts
    case "$1" in
    -w|--wait ) shift
        __wait__=1 ;;
    -- ) shift; break ;;
    * ) break ;;
    esac
done

[ "$1" -ge "0" ] 2>/dev/null || {
    echo "shell PID: invalid positive integer expression ‘$1’" >&2 && exit 1
}

if ((__wait__)); then
    while kill -s 0 "$1"; do
        sleep 5
    done
fi

shopt -s nullglob
rm "/dev/shm/mill-$1-"* 2>/dev/null
rm "/dev/shm/scale-$1-"* 2>/dev/null
