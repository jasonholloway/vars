#!/bin/bash

source "${VARS_PATH:-.}/common.sh"

main() {
  local type block

  setupBus

  while hear type _; do
    case "$type" in
        "readBlock")
            hear block
            readBlock "$block"
            ;;
    esac

    say "@END"
  done
}

readBlock() {
  local block="$1"

  decode block block

  local -a names=()
  local -a ins=()
  local -a outs=()
  local -a inMaps=()
  local -a outMaps=()
  local -a pins=()
  local -a flags=()
  local body macro n v i from to

  {
    if read -r line && [[ $line =~ ^#\++ ]]; then
        read -r _ macro <<<"$line"
        block=$(while read -r line; do echo "$line"; done)
    fi
  } <<<"$block"

  case $macro in
      map)
          block="$(awk -f "$VARS_PATH/macros/map.awk" <<<"$block")"
      ;;
  esac

  {
      local body0=""

      while read -r line; do
        case "$line" in
          '# n: '*)   for n in ${line:5}; do names+=($n); done ;;
          '# in: '*)  for n in ${line:6}; do ins+=($n); done ;;
          '# out: '*) for n in ${line:7}; do outs+=($n); done ;;
          '# pin: '*) pins+=(${line:7}) ;;
          '# cache'*) flags+=("C") ;;
          '')         ;;
          '#'*)       ;;
          *)          body0="$line"$'\n'; break ;;
        esac
      done

      local rest
      read -d0 -r rest
      body="${body0}${rest}"

  } <<<"$block"

  #process inMaps
  for i in "${!ins[@]}"; do
    n=${ins[$i]}
    if [[ $n =~ ^(.+)\<(.+)$ ]]; then
        to=${BASH_REMATCH[1]}
        from=${BASH_REMATCH[2]}
        ins[$i]=$from
        inMaps+=("$from $to")
    fi
  done

  #process outMaps
  for i in "${!outs[@]}"; do
    n=${outs[$i]}
    if [[ $n =~ ^(.+)\>(.+)$ ]]; then
        from=${BASH_REMATCH[1]}
        to=${BASH_REMATCH[2]}
        outs[$i]=$to
        outMaps+=("$from $to")
    fi
  done

  [[ ${#pins[@]} -gt 0 ]] && flags+=("P")

  (
    local IFS=,
    say "${names[*]};${ins[*]};${outs[*]};${flags[*]}"
  )

  for p in "${ins[@]}"; do
    say "in $p"
  done

  for p in "${inMaps[@]}"; do
    say "mapIn $p"
  done

  for p in "${pins[@]}"; do
    IFS='=' read -r n v <<<"$p"
    say "pin $n"
    encode v v
    say "$v"
  done

	encode body body
  say "run bash"
  say "$body"

  for p in "${outMaps[@]}"; do
    say "mapOut $p"
  done

  for p in "${outs[@]}"; do
    say "out $p"
  done

  say "fin"
}

main "$@"




# fids <- files.find
# outlines <- files.outline <- fids
#
# outlines -> |
# targets  -> |
#       deducer.deduce <> files.body
#             |        <> runner.run
#             |-> output
#
#



#
# blocks above will extract the outline and the body
# the body is just grist for whatever the correct interpreter is
# it will be stored within files
#
#
#    outlines <<< FILES -> BLOCKS
#    we want outlines served to the deducer up front as block specs
#
#    outline >>> RUNNER -> FILES
#
