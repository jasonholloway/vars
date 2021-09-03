#!/bin/bash
shopt -s extglob

declare -A \
  files \
  blocks \
  blockLookup \
  blockFiles \
  stashed \
  pinned \
  ins \
  outs \
  flags \
  binds \
  bodies \
  targetBlocks \
  targets

read filePaths
read targetBlockNames
read targetNames
read modes
read adHocs

[[ $modes =~ p ]] && export prepMode=1
[[ $modes =~ v ]] && export debugMode=1

export cacheDir=${CACHE:-$HOME/.vars/cache}
mkdir -p $cacheDir

export pinnedDir=${PINNED:-$HOME/.vars/pinned}
mkdir -p $pinnedDir

export contextFile="$HOME/.vars/context"
export outFile="$HOME/.vars/out"

export now=$(date +%s)

main() {
  readBlocks "$filePaths"
  collectTargets
  readPinned
  trimBlocks

  echo "targets ${!targetBlocks[@]}"

  {
    for b in $(orderBlocks); do
        local isTargetBlock=
        [[ ${targetBlocks[$b]} == 1 ]] && isTargetBlock=1
        
        local cacheKey=

        local -A boundIns=()
        for n in ${ins[$b]}; do
          local boundVal=${binds[$n]}
          if [[ $boundVal ]]; then
            boundIns[$n]=$boundVal
          else
            local pinnedVal=${pinned[$n]}
            if [[ $pinnedVal ]]; then
              binds[$n]=$pinnedVal
              boundIns[$n]=$pinnedVal
              echo "bind! pinned $n=$pinnedVal"
            else
                {
                    echo -n "pick $n "

                    if [[ -e $contextFile ]]; then
                        tac $contextFile |
                        sed -n '/^'$n'=/ { s/^.*=//p }' |
                        nl |
                        sort -k2 -u |
                        sort |
                        while read _ v; do echo -n ¦$v; done
                    fi

                    echo
                }

              read v

              if [[ $v == *! ]]; then
                v=${v%*!}
                echo "pin $n $v"
              fi

              binds[$n]=$v
              boundIns[$n]=$v
              echo "bind . $n=$v"
            fi
          fi
        done

        # pendingOuts: can elide the block if none set
        local -A pendingOuts=()
        for n in ${outs[$b]}; do
          if [[ -z ${binds[$n]} ]]; then
            pendingOuts[$n]=1
          fi
        done

        if [[ ${#pendingOuts[@]} -gt 0 || $isTargetBlock ]]; then

          local cacheResult=1
          if [[ ${flags[$b]} =~ C && ! $isTargetBlock ]]; then
            cacheKey=$(getCacheKey $b)
            tryGetCache binds $cacheKey #but this should just be on bindIns!!!
            cacheResult=$?
          fi

          if [[ ! $cacheResult -eq 0 ]]; then

            for i in ${ins[$b]}; do 
              local v=${binds[$i]}

              if [[ ${v:0:1} == ¦ ]]; then
                  echo "pick $i $v"
                  read v

                  if [[ $v == *! ]]; then
                    v=${v%*!}
                    echo "pin $i $v"
                  fi
              
                  binds[$i]=$v
                  echo "bind . $i=$v"
              fi
              
              v=${v//$'\30'/$'\n'}
              export "$i=$v"
            done
            
            {
                lines=$(
                    #below should be selected bindIns...
                    #and caching can be moved to the runner
                    local body
                    getBody $b

                    cmd=$body
                    echo "run ${binds[@]@A}"$'\031'"${cmd@A}" >&4

                    while read -r l; do
                        [[ $l == $'\023' ]] && break
                        echo "$l"
                    done
                 )
            } 4>&1

            declare -A boundOuts=()
            declare -A attrs=()

            { while read -r line; do
                case "$line" in
                    @set[[:space:]]+([[:word:]])[[:space:]]*)
                        read -r _ n v <<< "$line"
                        attrs[${n:1}]="$v"
                    ;;

                    +([[:word:]])=*)
                        n=${line%%=*}
                        v=${line#*=}
                        echo "bind $b $n=$v"
                        boundOuts[$n]=$v
                        binds[$n]=$v
                    ;;

                    *)
                        if [[ ! -z ${targetBlocks[$b]} ]]; then
                            echo "out $line"
                        fi 
                    ;;
                esac
              done <<< "$lines"
            } 3<&0

            if [[ ! -z ${attrs[cacheTill]} ]]; then
              [[ -z $cacheKey ]] && cacheKey=$(getCacheKey $b)
              setCache boundOuts $cacheKey ${attrs[cacheTill]}
            fi

          fi
        fi
    done

    for t in $targetNames; do
      local v=${binds[$t]}

      if [[ ${v:0:1} == ¦ ]]; then
        echo "pick $t $v"
        read v
      fi
                
      echo out $v
    done

    # blurt to context file
    { for t in ${!binds[@]}; do
        if [[ ${t:0:1} != '_' ]]; then
          echo $t=${binds[$t]//$'\n'/$'\30'}
        fi
      done } >> "$contextFile"

  } | tee "$outFile"
}

readPinned() {
  for f in $pinnedDir/*; do
    if [[ -e $f ]]; then
      local t=${f#$pinnedDir/}
      pinned[$t]=$(base64 -d "$f")
    fi
  done

  for adHoc in $adHocs; do
    local t v
    IFS='=' read -r t v <<< "$adHoc"
    pinned[$t]=$v
  done
}

readBlocks() {
  for file in $@; do

    local outline
    getOutline $file

    local i=0
    local IFS=$'\x02'
    for part in $outline; do
      i=$((i+1))
      n="$file|$i"

      blockFiles[$n]=$file
      blocks[$n]=$part

      while read -r line; do
        case $line in
          '# n:'*)
            local shortName=$(trim ${line#\#*:})
            blockLookup[$shortName]=$n
            ;;
          '# in:'*)
            ins[$n]=${line#\#*:}
          ;;
          '# out:'*)
            o=${line#\#*:}
            outs[$n]="${outs[$n]} $o"
          ;;
          '# cache'*)
            flags[$n]="${flags[$n]} C"
          ;;
        esac
      done <<< "$part"
    done
  done
}

collectTargets() {
  local n b

  for n in $targetNames; do
    targets[$n]=1
  done

  for n in $targetBlockNames; do
    for b in ${blockLookup[$n]}; do
        targetBlocks[$b]=1
    done
  done
}

trimBlocks() {
  local n b i

  local -A trimmables=()
  for b in ${!blocks[@]}; do trimmables[$b]=1; done

  for b in ${!targetBlocks[@]}; do
    unset trimmables[$b]
    for i in ${ins[$b]}; do targets[$i]=1; done
  done

  local -A pending=()
  for t in ${!targets[@]}; do pending[$t]=1; done

  local -A supplying=()
  for b in ${!blocks[@]}; do
    for t in ${outs[$b]}; do
      supplying[$t]="${supplying[$t]} $b"
    done
  done

  local -A seen=()
  
  while [ ${#pending[@]} -gt 0 ]; do
    for t in ${!pending[@]}; do

      if [[ -z ${pinned[$t]} ]]; then
        local bs=${supplying[$t]}

        for b in $bs; do
          unset trimmables[$b]

          for i in ${ins[$b]}; do
            if [ ! ${seen[$i]+xxx} ]; then
              pending[$i]=1
            fi
          done
        done
      fi

      seen[$t]=1
      unset pending[$t]
    done
  done

  for b in ${!trimmables[@]}; do
    unset blocks[$b]
  done

  if [[ $prepMode ]]; then
    for b in ${!targetBlocks[@]}; do
      unset blocks[$b]
    done
  fi
}

orderBlocks() {
  local b
  for b in ${!blocks[@]}; do
    for i in ${ins[$b]}; do
      echo "@$i $b"
    done

    for o in ${outs[$b]}; do
      echo "$b @$o"
    done
  done \
  | tsort \
  | sed '/^@/d'
}

getBody() {
  local b=$1

  if [[ ! -v bodies[$b] ]]; then
    local path=${b%|*}
    local file
    getFile $path

    local i=0
    local IFS=$'\x02'
    for part in $file; do
      i=$((i + 1))
      local bb="$path|$i"
      bodies[$bb]=$part
    done
  fi

  body=${bodies[$b]}
}

getOutline() {
  local path=$1
  local file

  if [[ ${path: -4} == .gpg ]]; then
    local lastMod=$(stat -c %Y $path)
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

getCacheKey() {
  local b=$1

  local file=${blockFiles[$b]}
  local lastMod=$(stat -c %Y $file)
  local flatIns=$(for t in ${!boundIns[@]}; do echo "$t=${boundIns[$t]}"; done)
  local key=$(echo "$file $lastMod $flatIns" | base64 -w0)
  local hash=$(echo $key | sha1sum | cut -d' ' -f1)
  echo "$hash|$key"
}

tryGetCache() {
  local -n _binds=$1
  local key=${2#*|}
  local hash=${2%|*}

  local file=$cacheDir/$hash
  [[ ! -e $file ]] && return 1

  IFS=$'\n' read -r -d '' foundKey foundExpiry foundBinds < "$file"
  
  [[ "$key" != "$foundKey" ]] && return 1
  [[ "$now" > "$foundExpiry" ]] && return 1

  while IFS=: read -r name encoded; do
    local val=$(echo $encoded | base64 -d)
    _binds[$name]="$val"
    echo "bind\` . $name=$val"

  done <<< "$foundBinds"
  
  return 0
}

setCache() {
  local -n _binds=$1
  local key=${2#*|}
  local hash=${2%|*}

  local file=$cacheDir/$hash
  local expiry=$3

  mkdir -p $cacheDir

  echo -e "$key\n$expiry" > "$file"

  for n in ${!_binds[@]}; do
    echo $n:$(echo "${_binds[$n]}" | base64 -w0) >> "$file"
  done
}

trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"   
    printf '%s' "$var"
}

main "$@"
