#!/bin/bash

declare RS=$'\030'
declare FS=$'\031'

setupBus() {
  exec 5<&0 6>&1
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

hear() {
  local _l

  while read -ru 5 _l; do
    case "$_l" in
      \#*) ;;
      +*)
          read -r "$@" <<<"${_l:1}"
          return 0;;
      *)
          error "Bad line read: ${_l}";;
    esac
  done

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

