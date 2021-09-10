#!/bin/bash
shopt -s extglob

: ${VARS_PATH:?VARS_PATH must be set!}

declare -a words=($@)
declare -a blocks=()
declare -a targets=()
declare -a flags=()
declare -a adHocs=()
declare w
declare shouldRun

colBindName='\033[0;36m'
colBindValue='\033[0;35m'
colGood='\033[0;32m'
colBad='\033[0;31m'
colNormal='\033[0m'
colDim='\e[38;5;240m'
colDimmest='\e[38;5;236m'

main() {
  local CACHE=~/.vars/cache
  mkdir -p $CACHE

  parseMany parseFlag \
  && {
       parseGet \
    || parseRun \
    || parsePin \
    || parseContext \
    || parsePrep \
    || parseLs \
    || parseLoad \
    || parseCache
    }

  [[ ! shouldRun -eq 1 ]] && exit 0

  [[ ${flags[*]} =~ q || ! -t 1 ]] && local quietMode=1
  [[ ${flags[*]} =~ v ]] && local verboseMode=1

  {
    # coproc { deduce; }
    coproc { stdbuf -oL $VARS_PATH/bus.awk; }
    exec 5<&${COPROC[0]} 6>&${COPROC[1]}

    {
        echo @ASK deduce
        echo $(findFiles 1 $PWD)
        echo ${blocks[*]}
        echo ${targets[*]}
        echo ${flags[*]}
        echo ${adHocs[*]}
        echo @YIELD
    } >&6

    while read -ru 5 type line; do
      echo "+++ $type $line" >&2
      case $type in

        "@PUMP") echo >&6;;
          
        targets)
            for src in $line; do
                IFS='|' read path index <<< "$src"
                shortPath=$(realpath --relative-to=$PWD $path) >&2
                src=${shortPath}$([[ $index ]] && echo "|$index")

                echo -e "${colDim}Running ${src}${colNormal}" >&2
            done
            ;;
        bound)
            set -x
            [[ ! $quietMode ]] && {
                read -r src key <<< "$line"
                read -ru 5 -d $'\031' val

                if [[ ${#val} -gt 80 ]]; then
                  val="$(echo "$val" | cut -c -80)..."
                fi

                [[ $key =~ (^_)|([pP]ass)|([sS]ecret)|([pP]wd) ]] && {
                  val='****'
                }

                IFS='|' read path index <<< "$src"
                shortPath=$(realpath --relative-to=$PWD $path) >&2
                src=${shortPath}$([[ $index ]] && echo "|$index")

                echo -e "${colBindName}${type:4}${key}=${colBindValue}${val} ${colDimmest}${src}${colNormal}" >&2
            }
            ;;

        out)
            if [[ $quietMode ]]; then
                echo -n "$line"
            else 
                echo "$line"
            fi
            ;;

        warn)
            echo -e "${colBad}${line}${colNormal}" >&2
            ;;

        pick) {
                read name rawVals <<< "$line"

                local val=$({
                    sed 's/¦//; s/¦/\n/g' <<< "$rawVals"
                } | fzy --prompt "${name}> ")

                echo $val >&6
            };;

        pin) {
                read key val <<< "$line"
                $VARS_PATH/context.sh pin "${key}=${val}" &> /dev/null
                echo -e "${colBindName}${key}<-${colBindValue}${val}${colNormal}" >&2
            };;

        run) {
                (
                    IFS=$'\031' read -r assignBinds assignCmd <<< "$line"
                    eval "$assignBinds"
                    eval "$assignCmd"

                    for n in ${!binds[@]}; do
                        export "$n=${binds[$n]}"
                    done

                    source $VARS_PATH/helpers.sh 

                    eval "$cmd"

                    echo
                    echo $'\023'
                ) >&6
            };;
        esac
    done

    exec 5<&- 6>&-

  } | render
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
    && parseNames targets \
    && shouldRun=1
}

parseRun() {
  parse1 '^(r|ru|run)$' \
    && parseNames blocks \
    && shouldRun=1
}

parsePrep() {
  parse1 '^(p|prep)$' \
    && flags+=(p) \
    && parseNames blocks \
    && shouldRun=1
}

parseLs() {
  parse1 '^(ls|list)$' \
    && {
      {
        parse1 '^([0-9]+)$' \
        && maxDepth=$w
      } || maxDepth=1

      files=$(findFiles $maxDepth $PWD)
      $VARS_PATH/list.sh "$files"
    }
}

parsePin() {
  parse1 '^(p|pi|pin)$' \
    && {
      {
        parse1 '^(l|li|lis|list|ls)$' \
        && $VARS_PATH/context.sh listPinned
      } || {
        parse1 '^(c|cl|clear)$' \
        && $VARS_PATH/context.sh clearPinned
      } || {
        parse1 '^(u|unpin|r|rm|remove)$' \
          && {
            parseMany "parseName targets" \
            && $VARS_PATH/context.sh unpin "${targets[@]}"
          }
      } || {
        parseMany "parseName targets" \
          && {
            $VARS_PATH/context.sh pin "${targets[@]}"
          }
      }
    }
}

parseContext() {
  parse1 '^(x|con|cont|conte|contex|context)$' \
      && {
          {
            parse1 '^(l|li|lis|list|ls)$' \
            && $VARS_PATH/context.sh list
          } || {
            parse1 '^(c|cl|clear)$' \
            && $VARS_PATH/context.sh clearContext
          } || {
            parse1 '^prev(ious)?$' \
            && $VARS_PATH/context.sh previous
          } || {
            $VARS_PATH/context.sh list
          }
        }
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
  parse1 '^-[a-zA-Z]+$' \
    && {
      local i
      for (( i=1 ; i < ${#w} ; i++ )); do
        flags+=(${w:i:1});
      done
    }
}

parseAdHocBind() {
  parse1 '^\w+=.+$' \
    && adHocs+=($w)
}

parseName() {
  local -n into=$1
  parse1 '.+' \
    && into+=($w)
}

parseNames() {
  parseMany "parseFlag || parseAdHocBind || parseName $1"
}

parseArg() {
  local w=${words[$i]}
  [[ ! -z $w ]] \
      && shift1 \
      && echo "$w"
}


findFiles() {
  depth=$1
  shift
  wds="$*"

  for wd in $wds; do
    (cd "$wd" && "$VARS_PATH/listDotFiles.sh" '@*' "$depth")
  done |
    sort |
    uniq
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

render() {
  "$VARS_PATH/render.sh"
}

main $@
