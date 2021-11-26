#!/bin/bash

[[ $__LIB_ASSOCARRAY ]] || source ${VARS_PATH}/lib/assocArray.sh 

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

export __COMMON=1
