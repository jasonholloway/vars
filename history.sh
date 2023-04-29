#!/bin/bash 
source "${VARS_PATH:-.}/common.sh"

declare histPath="$HOME/.vars/hist"

declare -A rawFiles files blocks

main() {
  local type rest
    
  setupBus
    
  while hear type rest; do
    case $type in
      commit) commit $rest;;
      dredgeLatest) dredgeLatest $rest;;
    esac

    say "@YIELD"
  done
}

commit() {
  local vn val path
  vn=shift
  val=shift
  path="$histPath/$vn"

  {
      date +%s
      echo "$val"
  } >> $path
}

dredgeLatest() {
  local vn
  vn=shift
  path="$histPath/$vn"

  if [[ -e "$path" ]]; then
    tail -n1 "$path" | { read -r _ val; say "$val"; }
  fi

  say "fin"
}

main "$@"
