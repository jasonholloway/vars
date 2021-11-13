#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh

A_print() {
		parp A_write "$@"
}

A_write() {
  local -n __r=$1
	local -n __str=$2
	local sep1=${3:-,}
  local sep2=${4:->}
  local n
  local -a acc=()

  for n in "${!__r[@]}"
  do acc+=("${n}${sep2}${__r[$n]}")
  done

  local IFS=$sep1
  __str="${acc[*]}"
}

A_write_ordered() {
  local -n __r=$1
	local -n __str=$2
	local sep1=${3:-,}
  local sep2=${4:->}
  local n
  local -a acc=()

  for n in "${!__r[@]}"
  do acc+=("${n}${sep2}${__r[$n]}")
  done

	a_reorder acc

  local IFS=$sep1
  __str="${acc[*]}"
}

A_read() {
  local -n __r=$1
	local __raw; arg_read "$2" __raw
	local sep1=${3:-,}
	local sep2=${4:->}
	
	local parts p k v

	IFS=$sep1 read -ra parts <<<"$__raw"

  for p in "${parts[@]}"; do 
		IFS=$sep2 read -r k v <<<"$p"
    __r[$k]=$v
  done
}

A_readArray() {
    local -n __r=$1
    local -n __a=$2
    local p

    for p in "${__a[@]}"
    do __r["$p"]=1
    done
}

A_printNice() {
		local -n __r=$1
		local k

		for k in "${!__r[@]}"
		do echo "$k: ${__r[$k]}"
		done
}

A_merge() {
    local -n __x=$1
    local -n __y=$2
    local k
    
    for k in "${!__y[@]}"
    do __x[$k]="${__y[$k]}"
    done
}

export __LIB_ASSOCARRAY=1
