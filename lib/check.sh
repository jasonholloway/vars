#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0;0m"

fail() {
		echo "@FAIL $*"
}

log() {
		echo "@LOG $*"
}

check() {
		local name="$1"
		echo "- ${name}?"

		{
				local -A vars=()

				gather vars
				local run="${vars[_]}"
				local input="${vars[INPUT]}"
				local expect="${vars[EXPECT]}"
				local after="${vars[THEN]}"
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
				
				if [[ $line =~ ^\.([A-Z0-9]+) ]]
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

export __LIB_CHECK=1
