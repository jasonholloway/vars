#!/bin/bash

#NEED TO BOTH FEED TO JQ AND CAPTURE...
#send captured string to stdout if jq doesn't like it

# TODO read first line
# if starts with '{' then pipe rest into jq
#
#

val="$(cat)"

if [[ -t 1 ]]; then
  jq --slurp -eC '.[]' 2>/dev/null || echo "$val" <<< "$val"
  # [[ $? == 4 ]] && echo "$val"
else
  echo "$val"
fi

