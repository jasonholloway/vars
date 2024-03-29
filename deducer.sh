#!/bin/bash
shopt -s extglob

source "${VARS_PATH:-.}/common.sh"

export pinnedDir="${PINNED:-$HOME/.vars/pinned}"
mkdir -p "$pinnedDir"

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
  local -A blocks blockNames targetBlocks modes pinned ins outs flags outlines
  local now=$(date +%s)

  readInputs
  readUserPins
  trimBlocks

  say "targets ${!targetBlocks[*]}"

  readBlockPins
  trimBlocks

  plan=$(orderBlocks)
  runBlocks <<<"$plan"
}

readInputs() {
  local raw bid n vbid

  # Unpack outlines
  hear raw
  for outline in $raw; do
    IFS=';' read -r bid rawBlockNames rawIns rawOuts rawFlags <<<"$outline" 

    blocks[$bid]=1
    outlines[$bid]=$outline

    if [[ $bid =~ ^get:([^ ]+) ]]; then
        blockNames[$bid]="$bid"
        ins[$bid]=${BASH_REMATCH[1]}
        outs[$bid]=""
        flags[$bid]=""
    else
        for n in ${rawBlockNames//,/ }; do
            blockNames[$n]="$bid"
        done

        ins[$bid]="${rawIns//,/ }"
        outs[$bid]="${rawOuts//,/ }"
        flags[$bid]="${rawFlags//,/ }"
    fi
  done

  # Set target blocks
  hear raw
  for n in $raw; do
      for bid in ${blockNames[$n]}; do
          targetBlocks[$bid]=1
      done
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

        if [[ ${blockPinned[$vn]} && ${blockPinned[$vn]} != $v ]]; then
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
  local -A trimmables pending supplying seen

  # put all known bids in trimmables
  # and for each build up the supplying map
  for bid in ${!blocks[*]}; do
    trimmables[$bid]=1

    for vn in ${outs[$bid]}; do
      supplying[${vn%\*}]+=" $bid"
    done
  done

  # note: supplying index could be built up front

  # remove targets from trimmables
  # and mark all target inputs as pending
  for bid in ${!targetBlocks[*]}; do
    unset "trimmables[$bid]"

    for vn in ${ins[$bid]}; do
      pending[${vn%\*}]=1
    done
  done
  
  
  while [[ ${#pending[@]} -gt 0 ]]; do
    for pvn in ${!pending[*]}; do #vns pre-trimmed here

      if [[ -z ${pinned[$pvn]} ]]; then
        for bid in ${supplying[$pvn]}; do
          unset "trimmables[$bid]"

          for ivn in ${ins[$bid]}; do
            ivn=${ivn%\*}
            if [[ -z ${seen[$ivn]} ]]; then
              pending[$ivn]=1
            fi
          done
        done
      fi

      seen[$pvn]=1
      unset "pending[$pvn]"
    done
  done

  for bid in ${!trimmables[*]}; do
    unset "blocks[$bid]"
  done
}

orderBlocks() {
  local bid vn

  {
    for bid in ${!targetBlocks[*]}; do
        echo "$bid @GOAL!" 
    done

    for bid in ${!blocks[*]}; do
        for vn in ${ins[$bid]}; do
            vn=${vn%\*}
            echo "@$vn $bid"
        done

        for vn in ${outs[$bid]}; do
            vn=${vn%\*}
            echo "$bid @$vn"
        done
    done
  } \
  | tsort \
  | sed '/^@/d'
}

runBlocks() {
  local bid ivn vn v isTargetBlock isNeeded source isSingleIn isMultiVal
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
    for vn in ${outs[$bid]}; do [[ -z ${binds[${vn%\*}]} ]] && isNeeded=1; done
    [[ ! $isNeeded ]] && continue

    # Bind in vars, either from pinned or via pick
    for ivn in ${ins[$bid]}; do
      vn=${ivn%\*}
        
      source=
      v=${binds[$vn]}
      v="${v#¦}"

      if [[ ! $v ]]; then
        v=${pinned[$vn]}
        if [[ $v ]]; then source=pinned
        else
          say "dredge $vn"
          say "@YIELD"
          hear v
          source=dredged
        fi
      fi

      isSingleIn=
      [[ ${ivn: -1} != '*' ]] && isSingleIn=1

      isMultiVal=
      [[ $v =~ ¦ ]] && isMultiVal=1

      if [[ -z $v || ( $isSingleIn && $isMultiVal ) ]]; then
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
    say "run ${flags[*]}"$'\031'"${outlines[$bid]}"
    for vn in ${!boundIns[@]}; do
        biv=${boundIns[$vn]}

        local -a vs=()
        split ¦ "${biv#¦}" vs
        
        for v in "${vs[@]}"; do
            say val $vn $v
        done
    done
    say "go"
    say "@YIELD"
    say "@END"

    while hear type line; do
      case "$type" in
          'fin') break;;

          'bind')
              read -r vn v <<<"$line"
              decode v v
              boundOuts[$vn]="${boundOuts[$vn]}¦${v#¦}"
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
      v=${v#¦}
      binds[$vn]=$v
      say "bound $bid $vn ${v//$'\n'/$'\60'}"
    done
  done

  say "fin"
}

main "$@"
