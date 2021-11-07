#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh

outline_create() {
		local -n __o=$1

		__o="; >"

		outline_setBid __o "$2"
		outline_setIns __o "$3"
		outline_setOuts __o "$4"
}

outline_read() {
		local -n __outline=$1

		local __str
		arg_read "$2" __str
		
		__outline=$__str
}

outline_write() {
		local -n __outline=$1
		local -n __str=$2
		__str=$__outline
}

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

		local __bid
		arg_read "$2" __bid

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

		local __ins
		arg_read "$2" __ins

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

		local __outs
		arg_read "$2" __outs

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
