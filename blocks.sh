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
  local -a pins=()
  local -a flags=()
  local body macro n v

  {
    if read -r line && [[ $line =~ ^#\++ ]]; then
        read -r _ macro <<<"$line"
        block=$(while read -r line; do echo "$line"; done)
    fi
  } <<<"$block"

  if [[ ! -z $macro ]]; then
      local macroFile="$VARS_PATH/macros/${macro}.awk"
      if [[ -e $macroFile ]]; then
          block="$(awk -f "$macroFile" <<<"$block")"
      fi
  fi

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

      [[ ${#pins[@]} -gt 0 ]] && flags+=("P")

      body="${body0}$(cat)"

  } <<<"$block"

  (
    local IFS=,
    say "${names[*]};${ins[*]};${outs[*]};${flags[*]}"
  )

  for p in "${pins[@]}"; do
    IFS='=' read -r n v <<<"$p"
    say "pin $n"
    encode v v
    say "$v"
  done

	encode body body
  say "body bash" #"say body bash"
  say "$body"

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
