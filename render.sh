#!/bin/bash

val="$(cat)"

if [[ -t 1 ]]; then
  jq '.' 2>/dev/null <<< "$val"
  [[ $? -ne 0 ]] && echo "$val"
else
  echo "$val"
fi

