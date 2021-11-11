#!/bin/bash

[[ $__LIB_STACK ]] || source lib/stack.sh
[[ $__LIB_ARRAY ]] || source lib/array.sh
[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh

smap_init() {
    stack_init ___m
}

smap_push() {
		local -n ____m=$1
    local raw

    local -A x=()
    stack_peek ____m raw
    A_read x "n:raw" '+' '='

		local -A y=()
		A_read y "$2" '+' '='
    
    A_merge x y
    
    A_write_ordered x raw '+' '='

    stack_push ____m n:raw

    # todo:
		# the merging needs some kind of callback
		# if the callback says no to the merge then the entire push is off
}

smap_pushA() {
    local -n ___m=$1
    local -n ___A=$2

    local str
    A_write_ordered ___A str '+' '='

    smap_push ___m n:str
}

smap_peek() {
    stack_peek "$@"
}

smap_pop() {
    stack_pop "$@"
}

smap_peekA() {
    local -n __m=$1
    local -n __A=$2

    local raw
    smap_peek __m raw
    A_read __A "n:raw" '+' '='
}

smap_popA() {
    local -n __m=$1
    local -n __A=$2

    local raw
    smap_pop __m raw
    A_read __A "n:raw" '+' '='
}

smap_read() {
		local -n __m=$1
    smap_init __m
    stack_read __m "$2"
}

smap_readArray() {
		local -n __m=$1
		local a p

		arg_read "$2" a

    local -A A=()
    for p in "${a[@]}"
    do A[$p]=1
    done

    smap_init __m
    smap_pushA __m A
}

smap_write() {
    stack_write "$@"
}








stackMap__op() {
    local -n __tab="$1"; shift
    local -n _undo="$1"; shift

    local op=$1; shift
    local key=$1; shift
    local rest=$*

    local insert=
    local remove=
    case $op in
        put) insert=1;;
        rem) remove=1;;
    esac

    local -a acc=()

    local IFS='='
    while read -r -d '+' k v
    do
        [[ ! $k ]] && continue
        
        if [[ $remove && $key == "$k" ]]
        then continue
        fi

        if [[ $insert ]]
        then
            if [[ $key < $k ]]
            then
                acc+=("${key}=${rest}")
                acc+=("${k}=${v}")
                _undo="rem $key"
                insert=
            elif [[ $key == "$k" ]]
            then
                acc+=("${key}=${rest}")
                _undo="put $key $v"
                insert=
            else
                acc+=("${k}=${v}")
            fi

            continue
        fi

        acc+=("${k}=${v}")

    done <<<"${__tab}+"

    if [[ $insert ]]
    then
        acc+=("${key}=${rest}")
        _undo="rem $key"
    fi

    local IFS=\+
    __tab="${acc[*]}"
}

stackMap_push() {
    local -n _tab="${1}_tab"
    local -n _undos="${1}_undos"

    local newK=$2
    local newV=$3
    local undo

    stackMap__op _tab undo put "$newK" "$newV"

    _undos+=("$undo")
}

stackMap_pop() {
    local -n _tab="${1}_tab"
    local -n _undos="${1}_undos"
    local undo cmd op rest

    stack_pop _undos undo

    local IFS=\;
    for cmd in $undo
    do
        unset IFS
        stackMap__op _tab _ $cmd
    done
}

stackMap_print() {
    local -n _t="${1}_tab"
    echo "$_t"
}

stackMap_ingest() {
    local -n _tab="${1}_tab"
    local -n _undos="${1}_undos"

    local undo
    local -a undoAcc=()

    mapfile -d\+ -t <<<"$2"

    for p in "${MAPFILE[@]}"
    do
        IFS='=' read -r k v <<<"${p%$'\n'}"

        stackMap__op _tab undo put "$k" "$v"
        undoAcc+=("$undo")
    done

    local IFS=\;
    _undos+=("${undoAcc[*]}")
}

export __LIB_SMAP=1
