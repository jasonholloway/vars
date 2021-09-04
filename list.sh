#!/bin/bash
paths="$1"
pwd="$PWD"

main() {
  while read -r path; do
    [[ -z $path || $path == "*.gpg" ]] && continue

    abs="${path%/*}"
    rel="$(realpath --relative-to="$pwd" "$abs")"
    file="${path##*/}"

    echo "!!BEGIN"
    echo "!!rel $rel"
    echo "!!file $file"
    echo "!!abs $abs"
    cat "$path"

  done <<< "$paths" |
      awk '
        /^!!BEGIN / {n=0}
        /^!!rel /   {rel=$2}
        /^!!file /  {file=$2}
        /^!!abs /   {abs=$2}
        /^#\++/     {n++}
        /^#\W+n:/   {print "B," rel "/" $3 "," abs "," file "," n ",B," $3}
        /^#\W+in:/  {for(i=3; i<=NF; i++) print "I," rel "/" $i "," abs "," file "," n ",I," $i}
        /^#\W+out:/ {for(i=3; i<=NF; i++) print "O," rel "/" $i "," abs "," file "," n ",O," $i}
      ' |
      sort |
      uniq
}

main "$@"
