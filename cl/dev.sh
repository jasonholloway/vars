#!/bin/bash

file=${1:?need to pass file!}

clear
clingo --verbose=0 $file

inotifywait -q -m -e close_write,moved_to,create . \
| while read d e f; do
    if [[ $f == $file ]]; then
      clear
      clingo --verbose=0 $f
    fi
  done

