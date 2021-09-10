#!/bin/bash 

declare -A files fileBlocks bodies

main() {
  while read -r type line; do
    case $type in
      file) getRawFile "$line"; echo "@END" ;;
      blocks) getBlocks "$line";;
      body) getBody "$line";;
    esac
  done
}

getBody() {
  local bid=$1
  loadBody $bid
  echo "${bodies[$bid]}"
}

getBlocks() {
  local path=$1
  loadBlocks $path
  echo "${fileBlocks[$path]}"
}

getRawFile() {
  local path=$1
  loadRawFile $path
  echo "${files[$path]}"
}

loadBlocks() {
  local path=$1

  if [[ ! -v fileBlocks[$path] ]]; then
    local i=-1
    {
      read -r lastMod
        
      while read -r -d$'\x02' block; do
        i=$((i+1))
        local bid="$path,$lastMod|$i"
        fileBlocks[$path]+=$bid$'\n'
        bodies[$bid]="$block"
      done
    } < <(getRawFile "$path" |
              sed -e '/^#+/i\\x02' -e '$a\\x02')
  fi
}

loadRawFile() {
  local path=$1

  if [[ ! -v files[$path] ]]; then
    files[$path]=$(
      local lastMod=$(stat -c %Y $path)
      echo $lastMod

      if [[ ${path: -4} == .gpg ]]; then
        gpg -dq --pinentry-mode loopback <"$path"
      else
        cat "$path"
      fi
      )
  fi
}

loadBody() {
  local bid=$1
  IFS='|' read -r file i <<<"$bid"
  IFS=',' read -r path lastMod <<<"$file"
  loadBlocks "$path"
}

main $@
