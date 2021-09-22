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
  local -A blocks blockNames targetBlocks modes pinned ins outs flags outlines
  local now=$(date +%s)

  readInputs
  readPinned

  trimBlocks
  say "targets ${!targetBlocks[*]}"

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

    for n in ${rawBlockNames//,/ }; do
        blockNames[$n]="$bid"
    done

    ins[$bid]="${rawIns//,/ }"
    outs[$bid]="${rawOuts//,/ }"
    flags[$bid]="${rawFlags//,/ }"

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

readPinned() {
  local file vn
  for file in "$pinnedDir"/*; do
    if [[ -e $file ]]; then
      vn=${file#"$pinnedDir"/}
      pinned[$vn]=$(base64 -d "$file") # should be lazily bash-decoded! TODO
    fi
  done
}

trimBlocks() {
  local bid vn ivn
  local -A trimmables pending supplying seen

  for bid in ${!blocks[*]}; do
    trimmables[$bid]=1

    for vn in ${outs[$bid]}; do
      supplying[$vn]+=" $bid"
    done
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
        for bid in ${supplying[$vn]}; do
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
    say "run ${flags[*]}"$'\031'"${boundIns[*]@A}"$'\031'"${outlines[$bid]}"
    say "@YIELD"

    while hear type line; do
      case "$type" in
          'bind')
              read -r vn v <<<"$line"
              decode v v
              boundOuts[$vn]=$v
          ;;

          'set')
              read -r n v <<< "$line"
              attrs[$n]="$v"
          ;;

          'fin') break;;
      esac
    done

    for vn in ${!boundOuts[*]}; do
      v=${boundOuts[$vn]}
      binds[$vn]=$v
      say "bound $bid $vn ${v//$'\n'/$'\60'}"
    done

    # say "fin"
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