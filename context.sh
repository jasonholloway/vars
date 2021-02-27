#!/bin/bash

outFile=$HOME/.vars/out
contextFile=$HOME/.vars/context
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
      clearContext) clearContext;;
      previous) previous;;
  esac
}

pin() {
  [[ $# -eq 0 ]] && exit
    
  local -A toAdd=()
  local -A fromContext=()

  for n in $@; do
    if [[ $n =~ ^[[:alnum:]]+$ ]]; then
      fromContext[$n]=1
    elif [[ $n =~ ^[[:alnum:]]+=.* ]]; then
      toAdd[${n%%=*}]=${n##*=}
    fi
  done 

  if [[ ${#fromContext[@]} > 0 && -e $contextFile ]]; then
    while read n b; do
      if [[ ${fromContext[$n]} -eq 1 ]]; then
        local xv
        read xv <<< "$(base64 -d <<< "$b")"
        toAdd[$n]=$xv
      fi
    done < $contextFile
  fi

  for n in ${!toAdd[@]}; do
    local v=${toAdd[$n]}
    local b=$(base64 -w0 <<< "$v")
    echo "$b" > "$pinnedDir/$n"
    echo "PINNED $n=$(crop 50 $v)" >&2
  done
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

clearContext() {
  echo '' > $contextFile
  echo "CLEARED CONTEXT" >&2
}

list() {
  if [[ -e $contextFile ]]; then
    while read n b; do
      read v <<< "$(base64 -d <<< "$b")"
      echo -e "$n\t$(crop 50 $v)"
    done < $contextFile
  fi
}

previous() {
  "$VARS_PATH/render.sh" "$(sed -n 's/^out //p' <$outFile)"
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
