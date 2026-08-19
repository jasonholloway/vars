#!/bin/bash

userDir=$HOME/.vars
outFile=$userDir/current/out
contextFile=$userDir/current/context
pinnedDir=$userDir/current/pinned
mkdir -p "$pinnedDir"

main() {
  cmd=${1:?no cmd!}
  shift

  case $cmd in
      pin) pin "$@";;
      unpin) unpin "$@";;
      list) list;;
      listPinned) listPinned;;
      clearPinned) clearPinned;;
      clearContext) clearContext;;
      previous) previous;;
      current) current;;
      listContexts) listContexts;;
      switchContext) switchContext "$1";;
      forkContext) forkContext "$1";;
  esac
}

pin() {
  [[ $# -eq 0 ]] && exit
    
  local -A toAdd=()

  for n in "$@"; do
    if [[ $n =~ ^_?[[:alnum:]]+=.* ]]; then
      toAdd[${n%%=*}]=${n#*=}
    fi
  done 

  for n in ${!toAdd[@]}; do
    local v=${toAdd[$n]}
    local b=$(base64 -w0 <<< "$v")
    echo "$b" > "$pinnedDir/$n"
    echo "PINNED $n=\"$(crop 50 $v)\"" >&2
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
  rm -f $contextFile
  echo "CLEARED CONTEXT" >&2
}

list() {
  if [[ -e $contextFile ]]; then
    {
        tac $contextFile |
        nl |
        sort -k2 -u |
        sort -r |
        cut -f2
    }
  fi
}

previous() {
  "$VARS_PATH/render.sh" <"$outFile"
  return 0
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

current() {
  cat "$userDir/currentName"
}

listContexts() {
  find $userDir/contexts -mindepth 1 -maxdepth 1 -type d -printf "%f\n"
}

switchContext() {
  cd $userDir

  name="$1"
  path="contexts/$name"

  if [[ -d $path ]]; then
    ln -sfv -T "$path" current \
    && echo "$name" >currentName
  fi
}

forkContext() {
  cd "$userDir"

  newName="${1}"
  currentName=$(current)

  cp -R "contexts/$currentName" "contexts/$newName" \
     && switchContext "$newName"
}

main "$@"
