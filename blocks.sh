#!/bin/bash

source "${VARS_PATH:-.}/common.sh"

declare -A outlines=()
declare -A blocks=()

main() {
  local type rest

  setupBus

  while hear type rest; do
    case "$type" in
      "outline")  outlineFiles "$rest" ;;
      "block")    getBlock "$rest" >&6; say fin ;;
      "pins")     getPins "$rest";;
    esac

    say "@YIELD"
  done
}

outlineFiles() {
  local -a fids=($@)
  local -a acc=()
  local bid section

  readFiles "${fids[*]}"

  for bid in "${bids[@]}"
  do
    acc+=(${outlines[$bid]})
  done
  
  say "${acc[*]}"
}

getBlock() {
  local bid=$1
  local v n type rest line

  if [[ $bid =~ ^get:(.+)$ ]]
  then
    v=${BASH_REMATCH[1]}
    cat <<-EOF
				in ${v}
				run bash
				echo \$${v}
EOF
  elif [[ $bid =~ ^shim:(.+)$ ]]
  then
      IFS=: read -r rawInMaps bid rawOutMaps <<<"${BASH_REMATCH[1]}"

      local -A inMaps=()
      A_read inMaps "v:$rawInMaps"

      local -A outMaps=()
      A_read outMaps "v:$rawOutMaps"

      getBlock "$bid" | 
        while read -r type rest; do
          case $type in
              "in") echo "in $rest" ;;
              "out") echo "out $rest" ;;
              "run")
                  for n in ${!inMaps[@]}
                  do echo "mapIn $n ${inMaps[$n]}"
                  done
                  
                  echo "run $rest"
                  read -r line
                  echo "$line"
              ;;
           esac
        done

      for n in ${!outMaps[@]}
      do echo "mapOut $n ${outMaps[$n]}"
      done
  else
    IFS='|' read -r fid _ <<<"$bid"
    readFiles "$fid"

    echo "${blocks[$bid]}"
  fi
}

readFiles() {
  local fids=($@)
  local bid section

  say "@ASK files"
  say "chop ${fids[*]}"
  say "@YIELD"

  while hear bid
  do
      [[ $bid == fin ]] && break
      
      hear section
      decode section section

      readSection "$bid" "$section"

      bids+=($bid)
  done

  say "@END"
}

readSection() {
  local bid=$1
  local section=$2

  local -a names=()
  local -a ins=()
  local -a outs=()
  local -a inMaps=()
  local -a outMaps=()
  local -a pins=()
  local -a flags=()
  local line body macro n v i from to

  {
    if read -r line && [[ $line =~ ^#\++ ]]; then
        read -r _ macro <<<"$line"
        section=$(IFS=; while read -r line; do echo "$line"; done)
    fi
  } <<<"$section"

  case $macro in
      map)
          section="$(awk -f "$VARS_PATH/macros/map.awk" <<<"$section")"
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
      IFS= read -d '' -r rest

      body="${body0}${rest}"

  } <<<"$section"

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

  outlines[$bid]=$(
    local IFS=,
    echo "${bid};${names[*]};${ins[*]};${outs[*]};${flags[*]}"
  )

  blocks[$bid]=$(
    for p in "${ins[@]}"; do
      echo "in $p"
    done

    for p in "${inMaps[@]}"; do
      echo "mapIn $p"
    done

    for p in "${pins[@]}"; do
      IFS='=' read -r n v <<<"$p"
      echo "pin $n"
      encode v v
      echo "$v"
    done

    encode body body
    echo "run bash"
    echo "$body"

    for p in "${outMaps[@]}"; do
      echo "mapOut $p"
    done

    for p in "${outs[@]}"; do
      echo "out $p"
    done
  )
}

getPins() { #To be removed...
  local bid=$1
  local fid type rest val
  
  IFS='|' read -r fid i <<<"$bid"
  readFiles "$fid"

  while read -r type rest; do
    case "$type" in
        pin)
          say "$rest"
          read -r val
          say "$val"
        ;;
    esac
  done <<<"${blocks[$bid]}"

  say "fin"
}

main "$@"
