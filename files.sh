#!/bin/bash 

cacheDir="$HOME/.vars/cache"

source "${VARS_PATH:-.}/common.sh"

declare -A rawFiles files bodies

main() {
  local type line
    
  setupBus
    
  while hear type line; do
    case $type in
      find) findFiles >&6;;
      raw) getRawFile "$line";;
      outline) getOutlines "$line";;
      body) getBody "$line";;
    esac

    say "@YIELD"
  done
}

getOutlines() {
  local fids hash cacheFile outlineList

  fids=$*

  hash=$(echo "$fids" | sha1sum)
  cacheFile="$cacheDir/O-${hash%% *}"

  if [[ -e $cacheFile ]]; then
    {
      read -r outlineList
      say "$outlineList"
      return
    } <"$cacheFile"
  fi

  local -a outlines=()

  loadFiles "$fids"
  
  for fid in $fids; do
    outlines+=("${files[$fid]}")
  done

  outlineList="${outlines[*]}"
  echo "$outlineList" >"$cacheFile"
  say "$outlineList"
}

getBody() {
  local bid=$1
  IFS='|' read -r fid i <<<"$bid"
  loadFile "$fid"

  local body="${bodies[$bid]}"
  encode body body
  echo "$body"
}

loadFiles() {
  local fids="$*"
    
  for fid in $fids; do
    loadFile "$fid"
  done
}

loadFile() {
  local fid bid hash cacheFile line i
  local -A acBodies
  local -a acOutlines

  fid=$1

  [[ -v "files[$fid]" ]] && return

  hash=$(echo "$fid" | sha1sum)
  cacheFile="$cacheDir/F-${hash%% *}"
  
  if [[ -e $cacheFile ]]; then
    {
      read -r line
      eval "$line"

      read -r line
      eval "$line"
    } <"$cacheFile"
  fi

  if [[ ! -v "acOutlines[@]" || ! -v "acBodies[@]" ]]; then
      {
        local i=0

        while read -r -d$'\x02' block; do
          local bid="$fid|$i"
          local outline bodyHints body

          encode block block

          say "@ASK blocks"
          say "readBlock"
          say "$block"
          say "@YIELD"
          hear outline
          hear bodyHints
          hear body

          acOutlines+=("$bid;$outline")
          acBodies[$bid]="$bodyHints"$'\n'"$body"
          i=$((i+1))
        done

        {
            echo "${acOutlines[*]@A}"
            [[ ! $fid =~ .gpg ]] && echo "${acBodies[*]@A}"
        } >"$cacheFile"

      } < <(
          getRawFile "$fid" |
                sed -e '/^#+/i\\x02' -e '$a\\x02'
          )
  fi

  files[$fid]=${acOutlines[*]}

  for bid in ${!acBodies[*]}; do
    bodies[$bid]=${acBodies[$bid]}
  done
}

getRawFile() {
  local fid=$1
  local path

  IFS=',' read -r path _ <<<"$fid"

  if [[ ! -v "rawFiles[$fid]" ]]; then
    rawFiles[$fid]=$(
      if [[ ${path: -4} == .gpg ]]; then
        gpg -dq --pinentry-mode loopback <"$path"
      else
        cat "$path"
      fi
      )
  fi

  echo "${rawFiles[$fid]}"
}

findFiles() {
	local pattern='@*'
	local peekDepth=2

	while read -r fid; do
			echo -n "${fid%.*} "
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
