#!/bin/bash
shopt -s extglob

source "${VARS_PATH:-.}/common.sh"

pts=${1:?need to pass pts}

outFile="$HOME/.vars/out"
cacheDir="$HOME/.vars/cache"

main() {
  local type block

  setupBus

  while hear type rest; do
    case "$type" in
        run)
            run $rest
            ;;
    esac

    say "@YIELD"
  done
}

run() {
    local cacheFile
    local runFlags blockFlags

    IFS=$'\031' read -r runFlags assignBinds outline <<< "$*"
    IFS=';' read -r bid _ _ blockFlags <<< "$outline"

    # TODO
    # shims should be unpacked before the ensuiong pipeline
    # which wil also allow us to cache em
    # TODO

    isCacheable=
    [[ $blockFlags =~ C ]] && isCacheable=1

    if [[ $isCacheable ]]; then
        local hash=$(echo "$bid $assignBinds" | sha1sum)
        cacheFile="$cacheDir/R-${hash%% *}"
    fi

    {
        runIt=1
        if [[ $isCacheable && -e $cacheFile ]]; then
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
                        echo @out ${boundIns[$vn]}
                    )
                ;;
                shim:*)
                    local rawInMaps bid2 rawOutMaps m
                    local -A inMaps outMaps
                    
                    IFS=':' read -r _ rawInMaps bid2 rawOutMaps <<<"$bid"

                    readAssocArray inMaps "$rawInMaps"
                    readAssocArray outMaps "$rawOutMaps"

                    say "@ASK files"
                    say "body $bid2"
                    say "@YIELD"
                    hear hint
                    hear body
                    say "@END"

                    decode body body

                    (
                      eval "$assignBinds"

                      for n in ${!boundIns[*]}; do
                        m=${inMaps[$n]}

                        [[ ! $m ]] \
                            && m=$n

                        [[ $m =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
                            && export "$m=${boundIns[$n]}"
                      done

                      source $VARS_PATH/helpers.sh 

                      eval "$body" <"$pts"
                    ) |
                      while read -r line; do
                        case $line in
                          @bind*)
                              read _ n v <<<"$line"

                              m=${outMaps[$n]}
                              [[ ! $m ]] && m=$n

                              echo "@bind $m $v"
                          ;;

                          *)
                              echo "$line"
                          ;;
                        esac
                      done
                ;;
                *)
                    say "@ASK files"
                    say "body $bid"
                    say "@YIELD"
                    hear hint
                    hear body
                    say "@END"

                    decode body body

                    (
                        eval "$assignBinds"

                        for n in ${!boundIns[*]}; do
                            if [[ $n =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
                            then
                                export "$n=${boundIns[$n]}"
                            fi
                        done

                        source $VARS_PATH/helpers.sh 

                        eval "$body" <"$pts"
                    )
                ;;
            esac \
            | {
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
                      while read -r line; do echo "$line"; done
                  fi
              }
        fi
    } \
    | {
        local fromCache=
        while read -r line; do
            case "$line" in
                @fromCache)
                    fromCache=1
                    # this should be somehow communicated back out to traces...
                ;;

                @bind[[:space:]][[:word:]]*)
                    read -r _ vn v <<< "$line"
                    say bind $vn $v
                ;;

                @set[[:space:]][[:word:]]*)
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
      } \
    | {
        >"$outFile"
    
        if [[ ${runFlags[*]} =~ "T" ]]; then
            while read -r line; do
                say out "$line"
                echo "$line" >>"$outFile"
            done
        fi
      }

    say fin
}

readAssocArray() {
  local -n _r=$1
  local raw=$2
  local IFS=${3:-,}
  local sep=${4:->}
  local p l r

  for p in $raw; do 
    IFS=$sep read l r <<<"$p"
    _r[$l]=$r
  done
}

main "$@"