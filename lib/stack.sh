#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh
[[ $__LIB_ARRAY  ]] || source lib/array.sh

stack_init() {
    local -n __a=$1
    __a=()
}

stack_push() {
    local -n __a=$1

    local _v
    arg_read "$2" _v
    
    local h=${#__a[@]}
    __a[$h]=$_v
}

stack_pop() {
    local -n __a=$1
    local -n __out=$2

    local c=${#__a[@]}
    local h=$((c-1))

    if [[ $c -gt 0 ]]
    then
        __out=${__a[$h]}
        unset "__a[$h]"
    else
        __out=
    fi
}

stack_peek() {
    local -n __a=$1
    local -n __out=$2

    local c=${#__a[@]}
    local h=$((c-1))

    if [[ $c -gt 0 ]]
    then __out=${__a[$h]}
    else __out=
    fi
}

stack_write() {
		local -n ___a=$1
		local -n __out=$2

    a_reverse ___a

    local IFS=$'\n'
		__out="${___a[*]}"

    a_reverse ___a
}

stack_read() {
    local -n ___a=$1

    local raw
    arg_read "$2" raw

    readarray -t ___a <<<"$raw"

    a_reverse ___a
}

export __LIB_STACK=1
