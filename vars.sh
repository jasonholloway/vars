#!/bin/bash
shopt -s extglob

: ${VARS_PATH:?VARS_PATH must be set!}

export CACHE=~/.vars/cache
mkdir -p $CACHE

main() {
  local debugMode=1
  local exportMode=1
  local prepMode=

  parseOpts $@

  files=$(findFiles)
  lines=$(deduce "$files" "$blocks" "$targets" $prepMode)

  while IFS=' ' read -r type line; do
    case $type in

      bind*)
        [[ $debugMode ]] && echo "${type:4}${line}" >&2
        [[ $exportMode ]] && export "$line"
        ;;

      out)
        echo "$line"
        ;;
    esac
  done <<< "$lines"
}

parseOpts() {
  case $1 in
      g|ge|get)
          shift
          targets=$@
          ;;
      r|ru|run)
          shift 
          blocks=$@
          ;;
      p|prep)
          shift 
          prepMode=1
          blocks=$@
          ;;
      ls|list)
          shift
          files=$(findFiles)
          $VARS_PATH/varsList.sh "$files"
          exit $?
          ;;
      load)
          shift
          $VARS_PATH/varsLoad.sh "$1" "$2"
          exit $?
          ;;
      c|cache)
          shift
          case $1 in
              clear)
                  rm -rf $CACHE/*
                  echo cleared cache
                  exit 0
                  ;;
              *)
                  find $CACHE -type d
                  ;;
          esac
          ;;
  esac
}

findFiles() {
  "$VARS_PATH/listDotFiles.sh" '@*'
}

deduce() {
  "$VARS_PATH/deduceVarBinds.sh" "$@"
}

readBlocks() {
  for a in $@
    do [[ $a =~ ^[^¦] ]] && echo $a
  done
}

readTargets() {
  for a in $@
    do [[ $a =~ ^¦ ]] && echo ${a:1}
  done
}

main $@
