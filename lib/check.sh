#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh
[[ $__LIB_ARRAY ]] || source lib/array.sh

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0;0m"

xcheck() {
	:
}

check() {
		local name="$1"

		[[ $CHK && ! $name =~ $CHK ]] && return

		echo "- ${name}?"

		{
				local -A vars=()

				gather vars
				local run="${vars[_]}"
				local input="${vars[<]}"
				local output="${vars[>]}"
				local output_rest="${vars[>_rest]}"
				local after="${vars[,]}"
				local ok=1

				# TODO need to check .out (via RESULT below)
				# ...
				#
				#

				gather vars < <(
						echo ".RESULT"
						eval "$run" <<<"$input"

						echo ".THEN"
						eval "$after"
				)

				local result="${vars[RESULT]}"

				local type rest flag
				while read -r type rest
				do
						case $type in
								@FAIL)
										ok=
										echo -e "${RED}Failed: $rest${NC}"
								;;
								@LOG)
										echo "$rest"
								;;
						esac
				done <<<"${vars[THEN]}"

				if [[ $output ]]
				then
						for flag in $output_rest; do
								case $flag in
										':s')
												output=$(sed -E 's/\s+/ /g' <<<"$output") 
												;;
										':d')
												echo "$result"
												;;
								esac
						done

						if [[ $ok && $output != $result ]]
						then
								ok=
								echo -e "${RED}Failed: bad output${NC}"
								diff --color=always -T <(echo "$output") <(echo "$result")
						fi
				fi

				if [[ $ok ]]; then echo -e "${GREEN}SUCCESS!!!${NC}"; fi
		} | sed 's/^/  /'

		echo
}

gather() {
		local -n __vars=$1
		local -a acc=()
		local vn=_
		local line rest

		while read -r line
		do
				if [[ $line =~ ^\.([A-Za-z0-9,<>]+)([[:space:]].*)?$ ]]
				then
						__vars[$vn]=$(IFS=$'\n'; echo "${acc[*]}")

						vn=${BASH_REMATCH[1]}
						rest="${BASH_REMATCH[2]}"
						trim rest

						acc=()
				else
						acc+=("$line")
				fi
		done

		__vars[$vn]=$(IFS=$'\n'; echo "${acc[*]}")
		__vars[${vn}_rest]=$rest
}

fail() {
		echo "@FAIL $*"
}

log() {
		echo "@LOG $*"
}

chk() {
		local vn="$1"
		local __v k

		case "$2" in
				==) ;&
				eq)
						eval "__v=\${${vn}}"
						[[ $__v == "$3" ]] || fail "$vn = $__v (expected _${3}_)"
						;;

				neq)
						eval "v=\${${vn}}"
						[[ $__v != "$3" ]] || fail "$vn = $__v (expected _${3}_)"
						;;

				exists)
						eval "__v=\${${vn}}"
						[[ $__v ]] || fail "$vn doesn't exist"
						;;

				has)
						k=$3
						a_has "$vn" "$3" || fail "$vn doesn't have $k"
						;;

				hasLen)
						eval "__v=\${#${vn}[*]}"
						[[ $__v -eq "$3" ]] || fail "$vn length is $__v (expected _${3}_)"
						;;
		esac
}

export __LIB_CHECK=1
