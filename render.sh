#!/bin/bash

#NEED TO BOTH FEED TO JQ AND CAPTURE...
#send captured string to stdout if jq doesn't like it

val="$(cat)"

if [[ -t 1 ]]; then
  jq -C . 2>/dev/null <<<"$val"
  [[ $? -ne 0 ]] && echo "$val"
else
  echo "$val"
fi

