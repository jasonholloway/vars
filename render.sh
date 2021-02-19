#!/bin/bash

jq -C . 2>/dev/null <<< "$@"

[[ $? -ne 0 ]] && echo "$@"

exit 0
