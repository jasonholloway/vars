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

outFile="$HOME/.vars/out"
cacheDir="$HOME/.vars/cache"

now=$(date +%s)

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
        stdbuf -oL $VARS_PATH/bus.awk -v PROCS="files:$VARS_PATH/files.sh;blocks:$VARS_PATH/blocks.sh;deducer:$VARS_PATH/deducer.sh"
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

              local val=$({
                  sed 's/¦//; s/¦/\n/g' <<< "$rawVals"
              } | fzy --prompt "${name}> ")

              echo $val >&6
              echo @YIELD >&6
          };;

      pin) {
              read -r key val <<< "$line"
              $VARS_PATH/context.sh pin "${key}=${val}" &> /dev/null
              echo -e "${colBindName}${key}<-${colBindValue}${val}${colNormal}" >&2
          };;

      run) {
              local cacheFile
              local runFlags blockFlags

              IFS=$'\031' read -r runFlags assignBinds outline <<< "$line"
              IFS=';' read -r bid _ _ blockFlags <<< "$outline"

              isCacheable=
              [[ $blockFlags =~ C ]] && isCacheable=1

              if [[ $isCacheable ]]; then
                  local hash=$(echo "$bid $assignBinds" | sha1sum)
                  cacheFile="$cacheDir/R-${hash%% *}"
              fi
              
              # also todo:
              # we want to do the below in a Runner, but with set pty via an arg
              # the Runner will then make sure the pty is used for stdin on the running subshell
              # this lets us delegate deeply into the broker

              {
                  runIt=1
                  
                  if [[ $isCacheable && ! $runFlags =~ T && -e $cacheFile ]]; then
                      {
                          read -r line
                          if [[ $line > $now ]]; then
                              echo @fromCache
                              cat
                              runIt=
                          fi
                      } <"$cacheFile"
                  fi

                  if [[ $runIt ]]; then
                      case "$bid" in
                          get:*)
                              vn="${bid##*:}"

                              (
                                  eval "$assignBinds"
                                  echo ${boundIns[$vn]}
                              )
                          ;;
                          *)
                              say "@ASK files"
                              say "body $bid"
                              say "@YIELD"
                              hear body
                              say "@END"

                              decode body body

                              hint="${body%%$'\n'*}"

                              (
                                  eval "$assignBinds"
                                  for n in ${!boundIns[*]}; do
                                      export "$n=${boundIns[$n]}"
                                  done

                                  source $VARS_PATH/helpers.sh 

                                  eval "${body#*$'\n'}"
                              )
                          ;;
                      esac |
                      {
                          if [[ $isCacheable ]]; then
                              local -a buff=()
                              local cacheFor
                              local cacheTill=0
                              
                              while read -r line; do
                                  case "$line" in
                                      "@cacheTill "*)
                                          read -r _ cacheTill _ <<<"$line"
                                          ;;

                                      "@cacheFor "*)
                                          read -r _ cacheFor _ <<<"$line"
                                          cacheTill=$((now + cacheFor))
                                          ;;

                                      *)
                                          buff+=("$line")
                                          echo "$line"
                                          ;;
                                  esac
                              done

                              echo $cacheTill >>"$cacheFile"
                              printf "%s\n" "${buff[@]}" >>"$cacheFile"
                          else
                              cat -
                          fi
                      }
                  fi

              } |
              {
                local fromCache=
                while read -r line; do
                    case "$line" in
                        @fromCache)
                            fromCache=1
                            # this should be somehow communicated back out to traces...
                        ;;
                        
                        @bind[[:space:]]+([[:word:]])[[:space:]]*)
                            read -r _ vn v <<< "$line"
                            say bind $vn $v
                        ;;

                        @set[[:space:]]+([[:word:]])[[:space:]]*)
                            read -r _ n v <<< "$line"
                            say set $n $v
                        ;;

                        @out*)
                            read -r _  v <<< "$line"
                            echo $v
                        ;;

                        +([[:word:]])=*)
                            vn=${line%%=*}
                            v=${line#*=}
                            say bind $vn $v
                        ;;

                        *)
                            echo $line
                        ;;
                    esac
                done
              } |
              { [[ ${runFlags[*]} =~ "T" ]] && cat; }

              say fin
              say @YIELD
          } | tee "$outFile";;
      esac
  done
}

list() {
  local fids outlines type line 

  say "@ASK files"
  say "find"
  say "@YIELD"
  hear fids
  say "outline $fids"
  say "@YIELD"
  hear outlines
  say "@END"

  for outline in $outlines; do
      IFS=\; read -r fid names _ outs <<<"$outline"

      local IFS=\,

      for name in $names; do
          echo "B;$name;$fid"
      done

      for out in $outs; do
          echo "O;$out;$fid"
      done
  done | sort | uniq

  # say "@ASK deducer"
  # say "deduce"
  # say "$outlines"
  # say "${blocks[*]}"
  # say "${targets[*]}"
  # say "${flags[*]}"
  # say "@YIELD"

  # local maxDepth=$1
  # files=$(findFiles $maxDepth $PWD)
  # $VARS_PATH/list.sh "$files"
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
      {
        parse1 '^([0-9]+)$' \
        && maxDepth=$w
      } || maxDepth=1

      cmds+=("list $maxDepth")
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

main "$@"
