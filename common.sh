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
    echo "${1//$'\n'/$'\x30'}"
}

decode() {
    echo "${1//$'\x30'/$'\n'}"
}

