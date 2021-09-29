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
  local -a flags=()
  local body macro

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
          '# cache'*) flags+=("C") ;;
          '#'*)       ;;
          *)          body0="$line"$'\n'; break ;;
        esac
      done

      body="${body0}$(cat)"

  } <<<"$block"

  (
    local IFS=,
    say "${names[*]};${ins[*]};${outs[*]};${flags[*]}"
  )

	encode body body

  say "bash" #hints for interpretation
  say "$body"
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
