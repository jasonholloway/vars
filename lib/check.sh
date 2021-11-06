#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0;0m"

check() {
		local name="$1"

		[[ $CHK && ! $name =~ $CHK ]] && return

		echo "- ${name}?"

		{
				local -A vars=()

				gather vars
				local run="${vars[_]}"
				local input="${vars[INPUT]}"
				local expect="${vars[EXPECT]}"
				local after="${vars[,]}"
				local ok=1

				gather vars < <(
						echo ".RESULT"
						eval "$run" <<<"$input"

						echo ".THEN"
						eval "$after"
				)

				local result="${vars[RESULT]}"

				local type rest
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

				if [[ $ok ]]; then echo -e "${GREEN}SUCCESS!!!${NC}"; fi
		} | sed 's/^/  /'

		echo


		# {
		# 		if [[ $result == $expect ]]; then
		# 				echo *PASSED*
		# 		else
		# 				echo *FAILED*
		# 				diff --color=always <(echo "$expect") <(echo "$result")
		# 		fi
		# 		echo
		# } | sed 's/^/  /'

}

gather() {
		local -n __vars=$1
		local -a acc=()
		local vn=_

		while read -r line
		do
				
				if [[ $line =~ ^\.([A-Z0-9,]+) ]]
				then
						__vars[$vn]=$(IFS=$'\n'; echo "${acc[*]}")
						vn=${BASH_REMATCH[1]}
						acc=()
				else
						acc+=("$line")
				fi
		done

		__vars[$vn]=$(IFS=$'\n'; echo "${acc[*]}")
}

fail() {
		echo "@FAIL $*"
}

log() {
		echo "@LOG $*"
}

chk() {
		local vn="$1"
		local v k

		case "$2" in
				==) ;&
				eq)
						eval "v=\${${vn}}"
						[[ $v == "$3" ]] || fail "$vn = $v (expected _${3}_)"
						;;

				neq)
						eval "v=\${${vn}}"
						[[ $v != "$3" ]] || fail "$vn = $v (expected _${3}_)"
						;;

				exists)
						eval "v=\${${vn}}"
						[[ $v ]] || fail "$vn doesn't exist"
						;;

				has)
						k=$3
						a_has "$vn" "$3" || fail "$vn doesn't have $k"
						;;

				hasLen)
						eval "v=\${#${vn}[*]}"
						[[ $v -eq "$3" ]] || fail "$vn length is $v (expected _${3}_)"
						;;
		esac
}

export __LIB_CHECK=1
