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
