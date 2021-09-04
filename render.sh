#!/bin/bash

if [[ -t 1 ]]; then
  jq -C . 2>/dev/null
  [[ $? -ne 0 ]] && cat
else
  cat
fi

exit 0
