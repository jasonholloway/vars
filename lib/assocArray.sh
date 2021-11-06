#!/bin/bash

A_print() {
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

A_read() {
  local -n _r=$1
  local raw=$2
	local parts p k v

	IFS=',' read -ra parts <<<"$raw"

  for p in "${parts[@]}"; do 
		IFS='>' read -r k v <<<"$p"
    _r[$k]=$v
  done
}

export __LIB_ASSOCARRAY=1
