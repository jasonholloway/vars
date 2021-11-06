#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh

outline_getBid() {
		local -n __outline=$1
		local -n __bid=$2

		__bid=

		if [[ $__outline =~ ^(.*)\; ]]
		then
				__bid="${BASH_REMATCH[1]}"
				trim __bid
		fi
}

outline_setBid() {
		local -n __outline=$1
		local -n __bid=$2

		if [[ $__outline =~ ^.*(\;.*\>.*)$ ]]
		then
				local rest="${BASH_REMATCH[1]}"
				__outline="${__bid}${rest}"
		fi
}

outline_getIns() {
		local -n __outline=$1
		local -n __ins=$2

		__ins=()

		if [[ $__outline =~ ^.*\;(.*)\> ]]
		then
				readarray -t -d ',' __ins <<<"${BASH_REMATCH[1]}"
				a_trimAll __ins
		fi
}

outline_setIns() {
		local -n __outline=$1
		local -n __ins=$2

		if [[ $__outline =~ ^(.*\;).*(\>.*)$ ]]
		then
				local IFS=,
				local sig="${__ins[*]}"
				unset IFS
				
				local parts=(${BASH_REMATCH[1]} ${sig} ${BASH_REMATCH[2]})

				__outline="${parts[*]}"
		fi
}

outline_getOuts() {
		local -n __outline=$1
		local -n __outs=$2

		__outs=()

		if [[ $__outline =~ ^.*\;.*\>(.*)$ ]]
		then
				readarray -t -d ',' __outs <<<"${BASH_REMATCH[1]}"
				a_trimAll __outs
		fi
}

outline_setOuts() {
		local -n __outline=$1
		local -n __outs=$2

		if [[ $__outline =~ ^(.*\;.*\>).*$ ]]
		then
				local IFS=,
				local sig="${__outs[*]}"
				unset IFS
				
				local parts=(${BASH_REMATCH[1]} ${sig})

				__outline="${parts[*]}"
		fi
}

export __LIB_OUTLINE=1
