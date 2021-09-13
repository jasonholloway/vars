#!/bin/bash

setupBus() {
  exec 5<&0 6>&1
}

say() {
  echo "$@" >&6
}

hear() {
  read -r "$@" <&5
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

