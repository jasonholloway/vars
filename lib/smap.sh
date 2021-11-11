#!/bin/bash

[[ $__LIB_STACK ]] || source lib/stack.sh
[[ $__LIB_ARRAY ]] || source lib/array.sh
[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh

smap_init() {
    local -n __m=$1
		__m=(0)
}

smap_push() {
		local -n __m=$1
    local raw

    local -A x=()
    smap_peek __m raw
    A_read x "n:raw" '+' '='

		local -A y=()
		A_read y "$2" '+' '='
    
    A_merge x y
    
    A_write_ordered x raw '+' '='

    __m+=($raw)
    ((__m[0]++))

    # todo:
		# the merging needs some kind of callback
		# if the callback says no to the merge then the entire push is off
}

smap_peek() {
		local -n ___m=$1
		local -n ___out=$2

    local h=${___m[0]}
    if [[ $h -gt 0 ]]
    then
        ___out=${___m[$h]}
    else
        ___out=
    fi
}

smap_pop() {
		local -n ___m=$1
		local -n ___out=$2

    local h=${___m[0]}
		___out=${___m[$h]}

    unset "___m[$h]"
		((___m[0]--))
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
		local line

		local raw
		arg_read "$2" raw

		__m=(0)

		while read -r line
		do
				local -A a=()
				A_read a "v:$line" '+' '='

				local str
				A_write_ordered a str '+' '='
				
				__m+=($str)
				((__m[0]++))
		done <<<"$raw"

    a_reverse __m 1
}

smap_write() {
		local -n __m=$1
		local -n __out=$2

    a_reverse __m 1
    local h=${__m[0]}
    __m[0]=

		local IFS=$'\n'
		__out="${__m[*]}"

    __m[0]=$h
    a_reverse __m 1
    
		trim __out
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
