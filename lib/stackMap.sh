#!/bin/bash

[[ $__LIB_STACK ]] || source ${VARS_PATH}/lib/stack.sh

stackMap_init() {
    local -n _t="${1}_tab"
    _t=""
    
    stack_init "${1}_stack"
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

export __LIB_STACKMAP=1
