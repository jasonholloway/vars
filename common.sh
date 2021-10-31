#!/bin/bash

setupBus() {
  exec 5<&0 6>&1
}

say() {
  echo "$@" >&6
}

error() {
	say "@ERROR $*"
	exit 1
}

hear() {
	local _l

	while read -ru 5 _l; do
		case "$_l" in
			'@PUMP')
					say "@PUMP";;
			*)
					read -r "$@" <<<"$_l"
					return 0;;
		esac
	done

	return 1
}


encode() {
  local -n input=$1
  local -n output=$2
	output="${input//$'\n'/$'\36'}"
}

decode() {
  local -n input=$1
  local -n output=$2
	output="${input//$'\36'/$'\n'}"
}


writeAssocArray() {
  local -n _r=$1
  local sep=${3:->}
  local n
  local -a acc=()

  for n in "${!_r[@]}"
  do acc+=("${n}${sep}${_r[$n]}")
  done

  local IFS=${2:-,}
  echo "${acc[*]}"
}

readAssocArray() {
  local -n _r=$1
  local raw=$2
  local IFS=${3:-,}
  local sep=${4:->}
  local p l r

  for p in $raw; do 
    IFS=$sep read l r <<<"$p"
    _r[$l]=$r
  done
}


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

stack_print() {
    local -n _s=$1
    echo "${_s[@]}"
}





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


perform() {
    stackMap_init m

    stackMap_push m B 2
    stackMap_push m C 3
    stackMap_push m A 1

    stackMap_ingest m "hamster=cheekimunki+chinchilla=Mark"

    stackMap_pop m
    
    stackMap_print m
}
