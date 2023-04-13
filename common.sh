#!/bin/bash

declare RS=$'\030'
declare FS=$'\031'

setupBus() {
  exec 5<&0 6>&1
}

declare _pad=0;

setPad() {
  _pad=$1
  say "@PAD $_pad"
}

say() {
  {
    if [[ $1 =~ ^@[A-Z] ]]; then
        echo "$@"
    else
        echo "+""$@"
    fi
  } >&6
}

error() {
  say "@ERROR $*"
  exit 1
}

declare _buff=""

hear() {
  local _l _line

  while [[ ! $_buff =~ ([^$'\n']*)$'\n'(.*)$ ]]
  do
    if [[ $_pad > 0 ]]
    then read -ru 5 -N $_pad _l
    else read -ru 5 _l; _l+=$'\n'
    fi

    _buff+=$_l
    # echo "BUFF: $_buff" >&2
  done

  _line=${BASH_REMATCH[1]}
  # echo "LINE: $_line" >&2
  _buff=${BASH_REMATCH[2]}
  # echo "BUFF: $_buff" >&2

  case "$_line" in
    \#*) ;;
    +*)
      read -r "$@" <<<"${_line:1}"
      return 0;;
    *)
      error "Bad line read: ${_line}";;
  esac

  return 1
}

split() {
  local -n _dest=$3
  local v

  local IFS=$1
  for v in $2; do
      _dest+=("$v")
  done
}

join() {
  local -n _src=$2
  local -n _dest=$3

  local IFS=$1
  _dest="${_src[*]}"
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

