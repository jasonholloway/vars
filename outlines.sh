#!/bin/bash

main() {
  while read -r path; do
    getOutline $path
  done
}

#cache outline, but only cache non-encrypted files

getOutline() {
  local file

  if [[ ${path: -4} == .gpg ]]; then
    local shadowPath="$cacheDir/S$(base64 -w0 <<< "$path$lastMod")"

    if [[ -e $shadowPath ]]; then
      outline="$(<"$shadowPath")"
    else
      getFile $path
      outline="$(sed -n '/^#\|\x02/p' <<< "$file")"
      echo "$outline" > "$shadowPath"
    fi
  else
    getFile $path
    outline=$file
  fi
}

getFile() {
  local path=$1
  
  if [[ ! -v files[$path] ]]; then
    local raw

    if [[ ${path: -4} == .gpg ]]; then
      raw=$(gpg -dq --pinentry-mode loopback <"$path")
    else
      raw=$(<"$path")
    fi

    files[$path]=$(sed 's/^#+.*/\x02/' <<< "$raw")
  fi

  file=${files[$path]}
}


main $@
