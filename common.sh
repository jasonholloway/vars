#!/bin/bash

setupBus() {
  exec 5<&0 6>&1
}

say() {
  echo "$@" >&6
}

hear() {
	local _l

	while read -ru 5 _l; do
		case "$_l" in
			'@PUMP')
					say "@PUMP";;
			*)
					read -r "$@" <<<"$_l"
					break;;
		esac
	done
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

