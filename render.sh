#!/bin/bash

if [[ -t 1 ]]; then
  jq -C . 2>/dev/null <<< "$@"
  [[ $? -ne 0 ]] && echo "$@"
else
  echo -n "$@"
fi

exit 0
