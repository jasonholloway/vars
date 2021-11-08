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
	local raw; arg_read "$2" raw
	local sep1=${3:-,}
	local sep2=${4:->}
	
	local parts p k v

	IFS=$sep1 read -ra parts <<<"$raw"

  for p in "${parts[@]}"; do 
		IFS=$sep2 read -r k v <<<"$p"
    __r[$k]=$v
  done
}

A_printNice() {
		local -n __r=$1
		local k

		for k in "${!__r[@]}"
		do echo "$k: ${__r[$k]}"
		done
}

export __LIB_ASSOCARRAY=1
