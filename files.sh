#!/bin/bash 

source "${VARS_PATH:-.}/common.sh"

declare -A rawFiles files bodies
declare fid rawFile

main() {
  local type line
    
  setupBus
    
  while hear type line; do
    case $type in
      raw) getRawFile "$line";;
      file) getBlocks "$line";;
      body) getBody "$line";;
      find) findFiles;;
    esac

    say "@END"
  done
}

getBody() {
  local bid=$1
  loadBody $bid
  encode "${bodies[$bid]}"
}

getBlocks() {
  local fid=$1
  loadBlocks $fid
  echo "${files[$fid]}"
}

getRawFile() {
  local path=$1
  loadRawFile $path
  echo "$fid"
  echo "$rawFile"
}

loadBlocks() {
  local fid=$1

  [[ -v "files[$fid]" ]] && return

  {
    local acc=""

    read -r fid

    {
      local i=0
      while read -r -d$'\x02' block; do

        local bid="$fid|$i"
        local outline body

        say "@ASK blocks"
        say "readBlock"
        say "$block"
        say "@YIELD"
        hear outline
        hear body
        say "@END"

        acc+="$bid"$'\n'"$outline"$'\n'
        bodies[$bid]="$body"
        i=$((i+1))
      done
    } < <(sed -e '/^#+/i\\x02' -e '$a\\x02' | tr $'\n' $'\36')

    files[$fid]="$acc"

  } < <(getRawFile "$fid")
}

loadRawFile() {
  local fid=$1

  if [[ ! -v "rawFiles[$fid]" ]]; then
    rawFiles[$fid]=$(
      if [[ ${path: -4} == .gpg ]]; then
        gpg -dq --pinentry-mode loopback <"$path"
      else
        cat "$path"
      fi
      )
  fi

  rawFile="${rawFiles[$fid]}"
}

loadBody() {
  local bid=$1
  IFS='|' read -r file i <<<"$bid"
  IFS=',' read -r path _ <<<"$file"
  loadBlocks "$path"
}

findFiles() {
	local pattern='@*'
	local peekDepth=2

	while read -r fid; do
			echo -n "${fid%%.*} "
	done < <(
			{ find ~+ -maxdepth "$peekDepth" -name "$pattern" -printf "%p,%T@\n"

          while cd ..; do
            find ~+ -maxdepth 1 -name "$pattern" -printf "%p,%T@\n"
            [[ $PWD = / ]] && exit 0
          done
      } | sort
	)

	echo
}

main "$@"
