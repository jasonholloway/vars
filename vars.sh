#!/bin/bash
shopt -s extglob

: ${VARS_PATH:?VARS_PATH must be set!}

source "${VARS_PATH:-.}/common.sh"

declare -a words=($@)
declare -a blocks=()
declare -a targets=()
declare -a flags=()
declare -a adHocs=()
declare -a cmds=()
declare w

colBindName='\033[0;36m'
colBindValue='\033[0;35m'
colGood='\033[0;32m'
colBad='\033[0;31m'
colNormal='\033[0m'
colDim='\e[38;5;240m'
colDimmest='\e[38;5;236m'

cacheDir="$HOME/.vars/cache"

pts=$(tty)

main() {
  mkdir -p $cacheDir

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

  [[ ${flags[*]} =~ q || ! -t 1 ]] && local quietMode=1
  [[ ${flags[*]} =~ v ]] && local verboseMode=1

  if [[ ${#cmds[@]} -gt 0 ]]; then
    {
      coproc {
        stdbuf -oL $VARS_PATH/bus.awk -v PROCS="files:$VARS_PATH/files.sh;blocks:$VARS_PATH/blocks.sh;deducer:$VARS_PATH/deducer.sh;runner:$VARS_PATH/runner.sh $pts"
      }
      exec 5<&${COPROC[0]} 6>&${COPROC[1]}

      eval "${cmds[@]}"

      exec 5<&- 6>&-
    } | render
  fi
}

run() {
  local fids outlines type line 

  say "@ASK files"
  say "find"
  say "@YIELD"
  hear fids
  say "outline $fids"
  say "@YIELD"
  hear outlines
  say "@END"

  say "@ASK deducer"
  say "deduce"
  say "$outlines"
  say "${blocks[*]}"
  say "${targets[*]}"
  say "${flags[*]}"
  say "@YIELD"

  while hear type line; do
    # echo "+++ $type $line" >&2
    case "$type" in

      fin)
          say "@END"
          break
          ;;

      error)
          hear line
          echo "$line" >&2
          exit 1
          ;;

      targets)
          for src in $line; do
              IFS='|' read path index <<< "$src"
              shortPath=$(realpath --relative-to=$PWD $path) >&2
              src=${shortPath}$([[ $index ]] && echo "|$index")

              echo -e "${colDim}Running ${src}${colNormal}" >&2
          done
          ;;

      bound)
          [[ ! $quietMode ]] && {
              read -r src key val <<< "$line"
              #unescape val here?? TODO

              if [[ ${#val} -gt 80 ]]; then
                val="$(echo "$val" | cut -c -80)..."
              fi

              [[ $key =~ (^_)|([pP]ass)|([sS]ecret)|([pP]wd) ]] && {
                val='****'
              }

              IFS='|' read path index <<< "$src"
              shortPath=$(realpath --relative-to=$PWD $path) >&2
              src=${shortPath}$([[ $index ]] && echo "|$index")

              case "$src" in
                  cache*) key="\`$key";;
                  pin*) key="!$key";;
              esac

              echo -e "${colBindName}${key}=${colBindValue}${val} ${colDimmest}${src}${colNormal}" >&2
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
              read -r name rawVals <<< "$line"
              rawVals=${rawVals#¦}
              rawVals=${rawVals//¦/$'\n'}

              local val=$(fzy --prompt "${name}> " <<< "$rawVals")

              echo "$val" >&6
              echo "@YIELD" >&6
          };;

      pin) {
              read -r key val <<< "$line"
              $VARS_PATH/context.sh pin "${key}=${val}" &> /dev/null
              echo -e "${colBindName}${key}<-${colBindValue}${val}${colNormal}" >&2
          };;

      esac
  done
}

list() {
  local fids outlines names outs ins

  say "@ASK files"
  say "find"
  say "@YIELD"
  hear fids
  say "outline $fids"
  say "@YIELD"
  hear outlines
  say "@END"

  local IFS=$' '
  for outline in $outlines; do
      IFS=\; read -r bid names ins outs <<<"$outline"

      local IFS=$','
      for name in $names; do
          echo "B;$name;$bid"
      done

      for inp in $ins; do
          echo "I;${inp%\*};$bid"
      done

      for out in $outs; do
          echo "O;${out%\*};$bid"
      done

  done | sort | uniq
}

filterList() {
    local type=$1
    while read -r line; do
        [[ ${line:0:2} == "$type;" ]] && echo "${line:2}"
    done
}

relativizeList() {
    local -A relDirs=()
    
    while read -r line; do
        IFS=\; read -r name bid _ <<<"$line"
        IFS=\| read -r fid _ <<<"$bid"
        IFS=\, read -r file _ <<<"$fid"

        relDir=${relDirs[$file]}

        if [[ ! $relDir ]]; then
          dir=$(dirname "$file")
          relDir=$(realpath --relative-to="$PWD" "$dir")
          relDirs[$file]=$relDir
        fi

        echo "$relDir/$name;$relDir;$line"
    done
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
    && {
      for t in $targets; do
        blocks+=("get:$t")
      done
      cmds+=("run")
    }
}

parseRun() {
  parse1 '^(r|ru|run)$' \
    && parseNames blocks \
    && {
      cmds+=("run")
    }
}

parsePrep() {
  parse1 '^(p|prep)$' \
    && flags+=(p) \
    && parseNames blocks \
    && {
      cmds+=("run")
    }
}

parseLs() {
  parse1 '^(ls|list)$' \
    && {
      cmds+=("list")

      {
        parse1 '^(b|bl|block|blocks)' \
          && cmds+=("| filterList B")
      } || {
        parse1 '^(o|out|outs)' \
          && cmds+=("| filterList O")
      } || {
        parse1 '^(i|in|ins)' \
          && cmds+=("| filterList I")
      }

      parse1 '^rel' \
        && cmds+=("| relativizeList")
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
        && rm -rf $cacheDir/* \
        && echo cleared cache!) \
      || find $cacheDir -type d
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

render() {
  source "$VARS_PATH/render.sh"
}

main "$@"
