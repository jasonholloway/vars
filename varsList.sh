#!/bin/bash
files="$1"

main() {
  scan "$files"
}

scan() {
  files=$(for f in $@; do [[ ${f: -4} == ".gpg" ]] || echo "$f"; done)

  awk '
    /#\W+n:/ {print "B," $3}
    /#\W+out:/ {for(i=3; i<=NF; i++) print "T," $i}
  ' <<< "$(cat $files)"
}

main "$@"
