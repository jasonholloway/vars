#!/bin/bash 

cacheDir="$HOME/.vars/cache"

source "${VARS_PATH:-.}/common.sh"

declare -A rawFiles files blocks

main() {
  local type rest
    
  setupBus
    
  while hear type rest; do
    case $type in
      find) findFiles >&6;;
      raw) getRawFile "$rest";;
      outline) getOutlines "$rest";;
      body) getBody "$rest";;
      pins) getPins "$rest";;
    esac

    say "@YIELD"
  done
}

getOutlines() {
  local fids hash cacheFile outlineList

  fids=$*

  hash=$(echo "$fids" | sha1sum)
  cacheFile="$cacheDir/O-${hash%% *}"

  if [[ -e $cacheFile && ! $DISABLE_VARS_CACHE ]]; then
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
  local fid type rest body
  
  IFS='|' read -r fid i <<<"$bid"
  loadFile "$fid"

  while read -r type rest; do
    case "$type" in
        body)
          say "$rest"
          read -r body
          say "$body"
          break
        ;;
    esac
  done <<<"${blocks[$bid]}"
}

getPins() {
  local bid=$1
  local fid type rest val
  
  IFS='|' read -r fid i <<<"$bid"
  loadFile "$fid"

  while read -r type rest; do
    case "$type" in
        pin)
          say "$rest"
          read -r val
          say "$val"
        ;;
    esac
  done <<<"${blocks[$bid]}"

  say "fin"
}

loadFiles() {
  local fids="$*"
    
  for fid in $fids; do
    loadFile "$fid"
  done
}

loadFile() {
  local fid bid hash cacheFile line i
  local -A acBlocks
  local -a acOutlines

  fid=$1

  [[ -v "files[$fid]" ]] && return

  hash=$(echo "$fid" | sha1sum)
  cacheFile="$cacheDir/F-${hash%% *}"
  
  if [[ -e $cacheFile && ! $DISABLE_VARS_CACHE ]]; then
    {
      read -r line
      eval "$line"

      read -r line
      eval "$line"
    } <"$cacheFile"
  fi

  if [[ ! -v "acOutlines[@]" || ! -v "acBlocks[@]" ]]; then
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
          acOutlines+=("$bid;$outline")

          acBlocks[$bid]=$(
            while hear line; do
                [[ $line == fin ]] && break
                echo "$line"
            done
          )

          i=$((i+1))
        done

        {
            echo "${acOutlines[*]@A}"
            [[ ! $fid =~ .gpg ]] && echo "${acBlocks[*]@A}"
        } >"$cacheFile"

      } < <(
          getRawFile "$fid" |
                sed -e '/^#+/i\\x02' -e '$a\\x02'
          )
  fi

  files[$fid]=${acOutlines[*]}

  for bid in ${!acBlocks[*]}; do
    blocks[$bid]="${acBlocks[$bid]}"
  done
}

getRawFile() {
  local fid=$1
  local path

  IFS=',' read -r path _ <<<"$fid"

  if [[ ! -v "rawFiles[$fid]" ]]; then
    rawFiles[$fid]=$(
      if [[ ${path: -4} == .gpg ]]; then
        gpg2 -dq --pinentry-mode loopback <"$path"
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
			{ find -L ~+ -maxdepth "$peekDepth" ! -readable -prune -o -name "$pattern" -printf "%p,%T@\n"

          while cd ..; do
            find ~+ -maxdepth 1 ! -readable -prune -o -name "$pattern" -printf "%p,%T@\n"
            [[ $PWD = / ]] && exit 0
          done
      } | sort
	)

	echo
}

main "$@"
