#!/bin/bash

stack_init() {
    local -n _s="${1}"
    _s=()
}

stack_push() {
    local -n _s=$1
    local v=$2
    local head=${#_s[@]}
    _s[$head]=$v
}

stack_pop() {
    local -n _s=$1
    local -n _out=$2
    local c=${3:-1}

    while [[ $c -gt 0 ]]
    do
      local head=${#_s[@]}
      _out=${_s[$((head-1))]}
      unset "_s[$((head-1))]"
      ((c--))
    done
}

stack_peek() {
    local -n _s=$1
    local -n _out=$2

    local head=${#_s[@]}
    _out=${_s[$((head-1))]}
}

stack_write() {
		local -n __s=$1
		local -n __out=$2
		__out="${__s[*]}"
}

stack_print() {
		parp stack_write "$@"
}

export __LIB_STACK=1
