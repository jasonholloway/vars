#!/bin/bash
shopt -s extglob

export CACHE=~/.vars/cache
mkdir -p $CACHE


main() {
  local debugMode=1
  local exportMode=1
  local prepMode=

  parseOpts $@

  files="$(listDotFiles '@*')"

  lines="$(deduceVarBinds "$files" "$blocks" "$targets" $prepMode)"

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
          files="$(listDotFiles '@*')"
          varsList "$files"
          exit $?
          ;;
      load)
          shift
          varsLoad "$1" "$2"
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
