#!/bin/bash
files="$1"

main() {
  while read -r file; do
    [[ $file == "*.gpg" ]] && continue

    echo "!!! $file"
    cat "$file"

  done <<< "$files" |
      awk '
        /^!!! /     {file=$2}
        /^#\W+n:/   {print "B," $3 "," file}
        /^#\W+in:/  {for(i=3; i<=NF; i++) print "I," $i "," file}
        /^#\W+out:/ {for(i=3; i<=NF; i++) print "O," $i "," file}
      ' |
      sort |
      uniq
}

main "$@"
