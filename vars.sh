#!/bin/bash
shopt -s extglob

: ${VARS_PATH:?VARS_PATH must be set!}

declare -a words=($@)
declare -a blocks=()
declare -a targets=()
declare -a flags=()
declare w

main() {
  local CACHE=~/.vars/cache
  mkdir -p $CACHE

  parseMany parseFlag \
  && {
       parseGet \
    || parseRun \
    || parsePrep \
    || parseLs \
    || parseLoad \
    || parseCache
    }

  [[ ${flags[@]} =~ v ]] && local debugMode=1

  [[ $debugMode ]] && {
    echo TARGETS: ${targets[@]}
    echo BLOCKS: ${blocks[@]}
    echo FLAGS: ${flags[@]}
  } >&2

  files=$(findFiles)
  lines=$(deduce ${files} $'\n'${blocks[@]} $'\n'${targets[@]} $'\n'${flags[@]})

  while IFS=' ' read -r type line; do
    case $type in

      bind*)
        [[ $debugMode ]] && echo "${type:4}${line}" >&2
        export "$line"
        ;;

      out)
        echo "$line"
        ;;
    esac
  done <<< "$lines"
}

shift1() {
  i=$((i + 1))
}

parse1() {
  local re=$1
  local _w=${words[$i]}
  [[ $_w =~ $re ]] \
      && w=$_w \
      && shift1
}

parseMany() {
  while eval "$@"; do :; done
}

parseGet() {
  parse1 '^(g|ge|get)$' \
    && parseNames targets
}

parseRun() {
  parse1 '^(r|ru|run)$' \
    && parseNames blocks
}

parsePrep() {
  parse1 '^(p|prep)$' \
    && flags+=(p) \
    && parseNames blocks
}

parseLs() {
  parse1 '^(ls|list)$' \
    && files=$(findFiles) \
    && $VARS_PATH/varsList.sh "$files"
}

parseLoad() {
  local count block
  parse1 '^load$' \
    && {
      parse1 '^[0-9]+$' && count=$w
    } \
    && {
      parse1 '.+' && block=$w
    } \
    && "$VARS_PATH/varsLoad.sh" "$count" "$block"
}

parseCache() {
  parse1 '^cache$' \
    && (
      (parse1 '^clear$' \
        && rm -rf $CACHE/* \
        && echo cleared cache!) \
      || find $CACHE -type d
    )
}

parseFlag() {
  parse1 '^-[a-zA-Z]$' \
  && flags+=(${w: -1})
}

parseName() {
  local -n into=$1
  parse1 '.+' \
    && into+=($w)
}

parseNames() {
  parseMany "parseFlag || parseName $1"
}

parseArg() {
  local w=${words[$i]}
  [[ ! -z $w ]] \
      && shift1 \
      && echo "$w"
}

parseOpts() {
  case $1 in
      -v)
          shift
          debugMode=1
          parseOpts $@
          ;;
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

