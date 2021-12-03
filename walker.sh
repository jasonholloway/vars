#!/bin/bash
shopt -s extglob

source "${VARS_PATH:-.}/common.sh"
[[ $__LIB_STACKMAP ]] || source ${VARS_PATH}/lib/stackMap.sh 

export pinnedDir="${PINNED:-$HOME/.vars/pinned}"
mkdir -p "$pinnedDir"

export contextFile="$HOME/.vars/context"

main() {
  local type line

  setupBus

  while hear type line; do
    case "$type" in
      "walk")
          walk
          ;;
    esac

    say "@YIELD"
  done
}

walk() {
  local x=0
  local -A binds ins outs flags

  readUserPins

  hear -a plan
  runBlocks plan
}

readUserPins() {
  local file vn

  # todo: try finding just inputs

  for file in "$pinnedDir"/*; do
    if [[ -e $file ]]; then # is this really needed???
      vn=${file#"$pinnedDir"/}
      binds[$vn]="P $(base64 -d "$file")" # should be lazily bash-decoded! TODO
    fi
  done
}

runBlocks() {
  local -n _plan="$1"
    
  local bid ol vn v source rawIns rawOuts bindType isTarget isNeeded
  local -a ins outs flags
  local -A boundIns boundOuts attrs
    
  for ol in "${_plan[@]}"; do
      
    boundIns=()
    boundOuts=()
    attrs=()

    isTarget=
    if [[ $ol =~ ^\* ]]; then
      isTarget=1
      ol=${ol:1}
    fi

    IFS=';' read -r bid _ rawIns rawOuts rawFlags <<<"$ol"
    IFS=',' read -a ins <<<"$rawIns"
    IFS=',' read -a outs <<<"$rawOuts"
    IFS=',' read -a flags <<<"$rawFlags"

    local isNeeded=
    for vn in "${outs[@]}"; do
      if [[ ! ${binds[$vn]} ]]; then
        isNeeded=1
        break
      fi
    done

    for flag in "${flags[@]}"; do
      [[ $flag = T ]] && isNeeded=1
    done

    [[ $isTarget ]] && isNeeded=1

    [[ ! $isNeeded ]] && continue

    # Bind in vars, either from pinned or via pick
    for vn in "${ins[@]}"; do
      source=

      read -r bindType v <<<"${binds[$vn]}"

      case "$bindType" in
          P)
              source=pinned
          ;;
          V)
          ;;
          *)
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
              source=dredged
          ;;
      esac

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
        binds[$vn]="V $v"
        say "bound $source $vn ${v//$'\n'/$'\60'}"
      fi
    done

    flags=()
    [[ $isTarget ]] && flags+=(T)

    # Run the block!

    say "@ASK runner"
    say "run ${flags[*]}"$'\031'"${boundIns[*]@A}"$'\031'"${ol}"
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
      binds[$vn]="V $v"
      say "bound $bid $vn ${v//$'\n'/$'\60'}"
    done
  done 

  say "fin"

  # Blurt all binds to context file at end
  {
    for vn in ${!binds[@]}; do
      if [[ ${vn:0:1} != '_' ]]; then
        read -r _ v <<<"${binds[$vn]}"
        echo "$vn=${v//$'\n'/$'\30'}"
      fi
    done
  } >> "$contextFile"
}

log() {
  :
  echo "$@" >&2
}

main "$@"
