#!/bin/bash
files="$1"

main() {
  scan "$files"
}

scan() {
  files=$(for f in $@; do [[ ${f: -4} == ".gpg" ]] || echo "$f"; done)

  { awk '
    /#\W+n:/ {print "B," $3}
    /#\W+in:/ {for(i=3; i<=NF; i++) print "I," $i}
    /#\W+out:/ {for(i=3; i<=NF; i++) print "O," $i}
    ' <<< "$(cat $files)"
  } | sort | uniq
}

main "$@"
