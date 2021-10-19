#!/bin/bash 

cacheDir="$HOME/.vars/cache"

source "${VARS_PATH:-.}/common.sh"

declare -A rawFiles files sections

main() {
  local type rest
    
  setupBus
    
  while hear type rest; do
    case $type in
      find)     findFiles;;
      chop)     chopFiles "$rest";;
    esac

    say "@YIELD"
  done
}

findFiles() {
	local pattern='@*'
	local peekDepth=2
  local -a fids=()

	while read -r fid
  do fids+=(${fid%.*})
	done < <(
			{ find ~+ -maxdepth "$peekDepth" ! -readable -prune -o -name "$pattern" -printf "%p,%T@\n"

          while cd ..; do
            find ~+ -maxdepth 1 ! -readable -prune -o -name "$pattern" -printf "%p,%T@\n"
            [[ $PWD = / ]] && exit 0
          done
      } | sort
	)

  say "${fids[*]}"
}

chopFiles() {
  local -a fids=($@)
  local section

  readFiles "${fids[@]}"

  for fid in ${fids[*]}
  do
      for sid in ${files[$fid]}
      do
          say "$sid"

          section=${sections[$sid]}
          encode section section
          say "$section"
      done
  done

  say "fin"
}

readFiles() {
  local fid section i sid
  local -a sids
    
  for fid in "$@"
  do
    sids=()

    [[ -v "files[$fid]" ]] && return

    i=0
    while read -r -d$'\x02' section
    do
      sid="$fid|$((i++))"
      sids+=($sid)
      sections[$sid]=$section
      files[$fid]="${sids[*]}"
    done < <(getRawFile "$fid" | sed -e '/^#+/i\\x02' -e '$a\\x02')
  done
}





# getOutlines() {
#   local fids hash cacheFile outlineList

#   fids=$*

#   hash=$(echo "$fids" | sha1sum)
#   cacheFile="$cacheDir/O-${hash%% *}"

#   if [[ -e $cacheFile && ! $DISABLE_VARS_CACHE ]]; then
#     {
#       read -r outlineList
#       say "$outlineList"
#       return
#     } <"$cacheFile"
#   fi

#   local -a outlines=()

#   loadFiles "$fids"
  
#   for fid in $fids; do
#     outlines+=("${files[$fid]}")
#   done

#   outlineList="${outlines[*]}"
#   echo "$outlineList" >"$cacheFile"
#   say "$outlineList"
# }

# getBody() {
#   local bid=$1
#   local fid type rest body
  
#   IFS='|' read -r fid i <<<"$bid"
#   loadFile "$fid"

#   while read -r type rest; do
#     case "$type" in
#         run)
#           say "$rest"
#           read -r body
#           say "$body"
#           break
#         ;;
#     esac
#   done <<<"${blocks[$bid]}"
# }

# getPins() {
#   local bid=$1
#   local fid type rest val
  
#   IFS='|' read -r fid i <<<"$bid"
#   loadFile "$fid"

#   while read -r type rest; do
#     case "$type" in
#         pin)
#           say "$rest"
#           read -r val
#           say "$val"
#         ;;
#     esac
#   done <<<"${blocks[$bid]}"

#   say "fin"
# }

# getBlock() {
#   local bid=$1
#   local fid

#   # here we must distinguish between shims and normal blocks
#   # we receive the shim bid, and...
#   # we either know of it already, and can quickly serve back its details
#   # (ie check block cache)
#   # and if we don't, then...
#   #
#   # blocks should be fetched from ./blocks.sh - the place for knowledge of shims etc
#   # the runner would ask blocks for the block script, and then it would be up to blocks 
#   # to ask files for the raw data
#   #
#   # which would mean, blocks would have a cache of blocks
#   # (seems ok) - files knows files, blocks knows blocks

#   # here we're peering into the bids, to work out what we need to do to support it
#   # which blocks should know, not us

#   # TODO:
#   # - files provides bids and rawblock resolution
#   # - blocks turns bids into outlines, and rawblocks into blocks
#   #
  
#   IFS='|' read -r fid _ <<<"$bid"
#   loadFile "$fid"

#   say "${blocks[$bid]}"

#   say "fin"
# }

# listSids() {
#   local fid
#   local -a sids=()

#   readFiles "$@"

#   for fid in "$@"
#   do sids+=(${files[$fid]})
#   done

#   say "${sids[@]}"
# }

# getSection() {
#   local sid="$1"
#   local section
  
#   IFS='|' read -r fid _ <<<"$sid"

#   readFiles "$fid"

#   section=${sections["$sid"]}
#   encode section section

#   say "$section"
# }




# loadFiles() {
#   local fids="$*"
    
#   for fid in $fids; do
#     loadFile "$fid"
#   done
# }

# loadFile() {
#   local fid bid hash cacheFile line i
#   local -A acBlocks
#   local -a acOutlines

#   fid=$1
#   log loadFile $fid

#   [[ -v "files[$fid]" ]] && return

#   hash=$(echo "$fid" | sha1sum)
#   cacheFile="$cacheDir/F-${hash%% *}"
  
#   if [[ -e $cacheFile && ! $DISABLE_VARS_CACHE ]]; then
#     {
#       read -r line
#       eval "$line"

#       read -r line
#       eval "$line"
#     } <"$cacheFile"
#   fi

#   if [[ ! -v "acOutlines[@]" || ! -v "acBlocks[@]" ]]; then
#       {
#         local i=0

#         log loadin $fid

#         while read -r -d$'\x02' block; do
#           local bid="$fid|$i"
#           local outline bodyHints body

#           encode block block

#           say "@ASK blocks"
#           say "readBlock $bid"
#           say "$block"
#           say "@YIELD"

#           hear outline
#           acOutlines+=("$bid;$outline")

#           acBlocks[$bid]=$(
#             while hear line; do
#                 [[ $line == fin ]] && break
#                 echo "$line"
#             done
#           )

#           ((i++))
#         done

#         {
#             echo "${acOutlines[*]@A}"
#             [[ ! $fid =~ .gpg ]] && echo "${acBlocks[*]@A}"
#         } >"$cacheFile"

#       } < <(
#           if [[ $fid =~ ^[a-z]+: ]] # is a special block?
#           then echo ""
#           else getRawFile "$fid" | sed -e '/^#+/i\\x02' -e '$a\\x02'
#           fi
#           )
#   fi

#   files[$fid]=${acOutlines[*]}

#   for bid in ${!acBlocks[*]}; do
#     blocks[$bid]="${acBlocks[$bid]}"
#   done
# }

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

log() {
    echo "$@" >&2
}

main "$@"
