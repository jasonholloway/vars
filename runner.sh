#!/bin/bash
shopt -s extglob

source "${VARS_PATH:-.}/common.sh"

pts=${1:?need to pass pts}
[[ $pts =~ not ]] && pts=/dev/null

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
    local line

    IFS=$'\031' read -r runFlags assignBinds outline <<< "$*"
    IFS=';' read -r bid _ _ blockFlags <<< "$outline"

    # TODO cache results based on actual block data, not bids
    # what matters isn't the bid, but the run block and the bound ins!!! TODO
    # these boundIns also need whittling down to exactly what the body needs TODO
    # this means the cache flag doesn't really need to be on the outline, as we need the hash of the body from the block
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
          {
            local -A outs=()
            local -A outMaps=()

            say "@ASK blocks"
            say "block $bid"
            say "@YIELD"

            (
                eval "$assignBinds"

                local v type rest from to
                local i=1

                while hear type rest; do
                    case "$type" in
                        "in")
                            boundIns["A$((i++))"]=${boundIns[$rest]}
                        ;;
                        "mapIn")
                            read -r from to <<<"$rest"
                            boundIns[$to]=${boundIns[$from]}
                        ;;
                        "run")
                            hear body
                            decode body body
                            ;;
                        "mapOut")
                            read -r from to <<<"$rest"
                            outMaps[$from]=$to
                            ;;
                        "out")
                            outs[$rest]=1
                            ;;
                        "fin")
                            say "@END"
                            break
                            ;;
                    esac
                done

                for n in ${!boundIns[*]}; do
                    if [[ $n =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
                    then
                        export "$n=${boundIns[$n]}"
                    fi
                done

                source $VARS_PATH/helpers.sh 

                while read -r line; do
                  case $line in
                    @bind*)
                        read _ n v <<<"$line"

                        m=${outMaps[$n]}
                        [[ ! $m ]] && m=$n

                        echo "@bind $m $v"
                    ;;

                    *)  echo "$line" ;;
                  esac
                done < <(eval "$body" <"$pts")
            )
          } \
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

main "$@"
