#!/bin/bash
shopt -s extglob

source "${VARS_PATH:-.}/common.sh"

export pinnedDir="${PINNED:-$HOME/.vars/pinned}"
mkdir -p "$pinnedDir"

export contextFile="$HOME/.vars/context"

main() {
  local type line

  setupBus

  while hear type line; do
    case "$type" in
      "deduce")
          deduce
          ;;
    esac

    say "@YIELD"
  done
}

deduce() {
  local plan
  local x=1
  local -A blocks blockNames targetBlocks modes pinned ins outs suppliers flags outlines
  local now=$(date +%s)

  readInputs
  readUserPins
  trimBlocks

  say "targets ${!targetBlocks[*]}"

  visitBlocks ${!targetBlocks[@]}

  readBlockPins
  trimBlocks

  plan=$(orderBlocks)
  runBlocks <<<"$plan"
}

readInputs() {
  local raw bid n vn vbid

  # Unpack outlines
  hear raw
  for outline in $raw; do
    IFS=';' read -r bid rawBlockNames rawIns rawOuts rawFlags <<<"$outline" 

    blocks[$bid]=1
    outlines[$bid]=$outline

    for n in ${rawBlockNames//,/ }; do
      blockNames[$n]="$bid"
    done

    ins[$bid]="${rawIns//,/ }"
    outs[$bid]="${rawOuts//,/ }"
    flags[$bid]="${rawFlags//,/ }"

    for vn in ${outs[$bid]}; do
      suppliers[$vn]+=" $bid"
    done
  done

  # Set target blocks
  hear raw
  for n in $raw; do
      for bid in ${blockNames[$n]}; do
          targetBlocks[$bid]=1
      done
  done
  
  # Create and set blocks for var targets
  hear raw
  for n in $raw; do
      vbid="get:$n"
      blocks[$vbid]=1
      outlines[$vbid]=$vbid
      targetBlocks[$vbid]=1
      ins[$vbid]="$n"
  done

  # Set mode flags
  hear raw
  for n in $raw; do
      modes[$n]=1
  done
}

readUserPins() {
  local file vn

  # todo: try finding just inputs

  for file in "$pinnedDir"/*; do
    if [[ -e $file ]]; then # is this really needed???
      vn=${file#"$pinnedDir"/}
      pinned[$vn]=$(base64 -d "$file") # should be lazily bash-decoded! TODO
    fi
  done
}

visitBlocks() {
  local bid n b

  for bid in "$@"
  do
    for n in ${ins[$bid]}; do
      visitBlocks ${suppliers[$n]}
    done

    if [[ ${flags[$bid]} =~ P ]]
    then
      local -A p=()
      getPins $bid

      local -A mapped=()
      for n in ${!p[@]}; do
         mapped[$n]="${n}%$((x++))"
      done
      
      rewritePinned $bid

      # for n in ${outs[$bid]}; do
      #   suppliers[$n]=$newBid
      # done
    fi
  done
}

rewritePinned() {
  local bid=$1
  local n m newBid

  for n in ${ins[$bid]}; do
    rewritePinned ${suppliers[$n]} 
  done

  newBid="shim:"

  for n in ${ins[$bid]}; do
    m=${mapped[$n]}
    [[ $m ]] && newBid+="$m>$n"
  done

  if [[ ${#newBid} -gt 5 ]]
  then
    newBid+=":${bid}:"

    for n in ${outs[$bid]}; do
        m=${mapped[$n]}

        if [[ ! $m ]]; then
          m="${n}%$((x++))"
          mapped[$n]=$m
        fi

        newBid+="$n>$m"
    done

    mapped[$bid]=$newBid

    # todo: below...
    ins[$newBid]=""
    outs[$newBid]=""
    suppliers[""]=$newBid
    flags[$newBid]="" #all except P

    # todo: outs shouldn't be mapped on root!

    echo "$bid -> $newBid" >&2
  fi
}

getPins() {
  local bid=$1

  say "@ASK files"
  say "pins $bid"
  say "@YIELD"

  while hear line; do
    [[ $line == fin ]] && break

    vn="$line"
    hear v

    p[$vn]=$v
  done

  say "@END"
}

readBlockPins() {
  local bid vn v
  local -A blockPinned=()

  for bid in "${!blocks[@]}"; do
    if [[ ${flags[$bid]} =~ P ]]; then
        
      say "@ASK files"
      say "pins $bid"
      say "@YIELD"

      while hear line; do
        [[ $line == fin ]] && break

        vn="$line"
        hear v

        if [[ ${blockPinned[$vn]} ]]; then
          error "clash of blockPins for $vn: $v vs ${blockPinned[$vn]}"
        fi

        blockPinned[$vn]=$v
        pinned[$vn]=$v
      done

      say "@END"
    fi
  done
}

trimBlocks() {
  local bid vn ivn
  local -A trimmables pending seen

  for bid in ${!blocks[*]}; do
    trimmables[$bid]=1
  done

  for bid in ${!targetBlocks[*]}; do
    unset "trimmables[$bid]"

    for vn in ${ins[$bid]}; do
      pending[$vn]=1
    done
  done
  
  while [[ ${#pending[@]} -gt 0 ]]; do
    for vn in ${!pending[*]}; do

      if [[ -z ${pinned[$vn]} ]]; then
        for bid in ${suppliers[$vn]}; do
          unset "trimmables[$bid]"

          for ivn in ${ins[$bid]}; do
            if [[ -z ${seen[$ivn]} ]]; then
              pending[$ivn]=1
            fi
          done
        done
      fi

      seen[$vn]=1
      unset "pending[$vn]"
    done
  done

  for bid in ${!trimmables[*]}; do
    unset "blocks[$bid]"
  done
}

orderBlocks() {
  local bid vn

  for bid in ${!blocks[*]}; do
    for vn in ${ins[$bid]}; do
      echo "@$vn $bid"
    done

    for vn in ${outs[$bid]}; do
      echo "$bid @$vn"
    done
  done \
  | tsort \
  | tee /dev/stderr \
  | sed '/^@/d'
}

runBlocks() {
  local bid vn v isTargetBlock isNeeded source
  local -a flags
  local -A binds boundIns boundOuts attrs
    
  while read -r bid; do
    boundIns=()
    boundOuts=()
    attrs=()

    isTargetBlock=
    [[ ${targetBlocks[$bid]} ]] && isTargetBlock=1

    # Can skip if nothing needed
    isNeeded=$isTargetBlock
    for vn in ${outs[$bid]}; do [[ -z ${binds[$vn]} ]] && isNeeded=1; done
    [[ ! $isNeeded ]] && continue

    # Bind in vars, either from pinned or via pick
    for vn in ${ins[$bid]}; do
      source=
      v=${binds[$vn]}

      if [[ ! $v ]]; then

        v=${pinned[$vn]}
        if [[ $v ]]; then source=pinned
        else
          #yield to history-dredging process here... TODO
          v=$(
            if [[ -e $contextFile ]]; then
                tac $contextFile |
                sed -n '/^'$vn'=/ { s/^.*=//p }' |
                nl |
                sort -k2 -u |
                sort |
                while read _ v; do echo -n ¦$v; done
            fi
            )
        fi
      fi

      if [[ -z $v || ${v:0:1} == '¦' ]]; then
        say "pick $vn $v"
        say "@YIELD"
        hear v

        if [[ ${v: -1} == '!' ]]; then
          v=${v:: -1}
          say "pin $vn $v"
        fi

        source=picked
      fi

      boundIns[$vn]=$v

      if [[ $source ]]; then
        binds[$vn]=$v
        say "bound $source $vn ${v//$'\n'/$'\60'}"
      fi
    done

    flags=()
    [[ ${targetBlocks[$bid]} ]] && flags+=(T)

    # Run the block!

    say "@ASK runner"
    say "run ${flags[*]}"$'\031'"${boundIns[*]@A}"$'\031'"${outlines[$bid]}"
    say "@YIELD"
    say "@END"
    while hear type line; do
      case "$type" in
          'fin') break;;

          'bind')
              read -r vn v <<<"$line"
              decode v v
              boundOuts[$vn]=$v
          ;;

          'set')
              read -r n v <<< "$line"
              attrs[$n]="$v"
          ;;

          *) say "$type $line";;
      esac
    done

    for vn in ${!boundOuts[*]}; do
      v=${boundOuts[$vn]}
      binds[$vn]=$v
      say "bound $bid $vn ${v//$'\n'/$'\60'}"
    done
  done

  say "fin"

  # Blurt all binds to context file at end
  {
    for vn in ${!binds[@]}; do
      if [[ ${vn:0:1} != '_' ]]; then
        echo "$vn=${binds[$vn]//$'\n'/$'\30'}"
      fi
    done
  } >> "$contextFile"
}

main "$@"
