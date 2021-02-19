#!/bin/bash

lastFile=$HOME/.vars/last
pinnedDir=$HOME/.vars/pinned
mkdir -p "$pinnedDir"

main() {
  cmd=${1:?no cmd!}
  shift

  case $cmd in
      pin) pin $@;;
      unpin) unpin $@;;
      list) list;;
      listPinned) listPinned;;
      clearPinned) clearPinned;;
      clearContext) clearLast;;
      previous) previous;;
  esac
}

pin() {
  [[ $# -eq 0 ]] && exit
    
  local -A names
  for n in $@; do
    names[$n]=1
  done 

  if [[ -e $lastFile ]]; then
    while read n b; do
      if [[ ${names[$n]} -eq 1 ]]; then
        read v <<< "$(base64 -d <<< "$b")"
        echo "$b" > "$pinnedDir/$n"
        echo "PINNED $n=$(crop 50 $v)" >&2
      fi
    done < $lastFile
  fi
}

unpin() {
  [[ $# -eq 0 ]] && exit
    
  for n in $@; do
    rm -f $pinnedDir/$n
    echo "UNPINNED $n" >&2
  done 
}


listPinned() {
  for f in $pinnedDir/*; do
    if [[ -e $f ]]; then
      local n=${f#$pinnedDir/}
      read v <<< "$(base64 -d $f)"
      echo -e "$n\t$(crop 50 $v)"
    fi
  done
}

clearPinned() {
  rm -f $pinnedDir/*
  echo "UNPINNED ALL" >&2
}

clearLast() {
  echo '' > $lastFile
  echo "CLEARED CONTEXT" >&2
}

list() {
  if [[ -e $lastFile ]]; then
    while read n b; do
      read v <<< "$(base64 -d <<< "$b")"
      echo -e "$n\t$(crop 50 $v)"
    done < $lastFile
  fi
}

previous() {
  "$VARS_PATH/render.sh" "[[\"PREVIOUS\",\"RESULT\",\"HERE\"]]"
}

crop() {
  local c=$1
  shift
  local rest="$@"

  if [[ ${#rest} -gt $c ]]; then
    echo $(cut -c -$c <<< "$rest")...
  else
    echo "$rest"
  fi
}

main $@
