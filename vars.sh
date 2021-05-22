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

  [[ ${flags[@]} =~ q || ! -t 1 ]] && local quietMode=1
  [[ ${flags[@]} =~ v ]] && local verboseMode=1

  {
    coproc { deduce; }
    exec 5<&${COPROC[0]} 6>&${COPROC[1]}

    {
        echo $(findFiles)
        echo ${blocks[@]}
        echo ${targets[@]}
        echo ${flags[@]}
        echo ${adHocs[@]}
    } >&6

    while read -ru 5 type line; do
      case $type in
        bind*)
            [[ ! $quietMode ]] && {
                local d

                if [[ ${#line} -gt 100 ]]; then
                    d="$(echo "$line" | cut -c -100)..."
                else
                    d="$line"
                fi

                key="${d%%=*}"
                val="${d#*=}"

                [[ $key =~ (^_)|([pP]ass)|([sS]ecret)|([pP]wd) ]] && {
                    val='****'
                }

                echo -e "${colBindName}${type:4}${key}=${colBindValue}${val}${colNormal}" >&2
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

        tty) {
                (
                    IFS=$'\x1C' read ctx cmd <<< "$line"

                    while IFS='=' read -d$'\31' -r n v; do
                        v=${v//$'\32'/ }
                        v=${v//$'\30'/$'\n'}
                        export "$n=$v"
                    done <<< "$ctx"

                    source $VARS_PATH/helpers.sh 

                    eval "$cmd" >&2 #output could be parsed from here...
                )

                echo done >&6 #todo: could pipe response from above back
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
      files=$(findFiles)
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

render() {
  "$VARS_PATH/render.sh" "$(</dev/stdin)"
}

main $@
