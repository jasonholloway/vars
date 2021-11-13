#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh
[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh

ol_create() {
		local -n __o=$1
		local raw

		__o="; >"

		ol_setBid __o "$2"
		ol_setIns __o "$3"
		ol_setOuts __o "$4"
}

ol_read() {
		local -n __outline=$1

		local __str
		arg_read "$2" __str
		
		__outline=$__str
}

ol_write() {
		local -n __outline=$1
		local -n __str=$2
		__str=$__outline
}

ol_getBid() {
		local -n __outline=$1
		local -n __bid=$2

		__bid=

		if [[ $__outline =~ ^(.*)\; ]]
		then
				__bid="${BASH_REMATCH[1]}"
				trim __bid
		fi
}

ol_setBid() {
		local -n __outline=$1

		local __bid
		arg_read "$2" __bid

		if [[ $__outline =~ ^.*(\;.*\>.*)$ ]]
		then
				local rest="${BASH_REMATCH[1]}"
				__outline="${__bid}${rest}"
		fi
}

ol_getRest() {
		local -n __outline=$1
		local -n __rest=$2

		__rest=

		if [[ $__outline =~ \{([^\{}]*)\}$ ]]
		then
				__rest="${BASH_REMATCH[1]}"
		fi
}

ol_setRest() {
		local -n __outline=$1

		local __rest
		arg_read "$2" __rest

		if [[ $__outline =~ ^(.*)[[:space:]]+(\{[^\{]*\})$ ]]
		then
				local main="${BASH_REMATCH[1]}"
				__outline="${main} {${__rest}}"
		else
				__outline+=" {${__rest}}"
		fi
}

ol_getIns() {
		local -n __outline=$1
		local -n __ins=$2

		__ins=()

		if [[ $__outline =~ ^.*\;(.*)\> ]]
		then
				local matched=${BASH_REMATCH[1]}
				trim matched
				IFS=, read -ra __ins <<<"$matched"
		fi
}

ol_setIns() {
		local -n __outline=$1

		local -a __ins
		arg_read "$2" __ins

		if [[ $__outline =~ ^(.*\;).*(\>.*)$ ]]
		then
				a_reorder __ins
				
				local IFS=,
				local sig="${__ins[*]}"
				unset IFS
				
				local parts=(${BASH_REMATCH[1]} ${sig} ${BASH_REMATCH[2]})

				__outline="${parts[*]}"
		fi
}

ol_getOuts() {
		local -n __outline=$1
		local -n __outs=$2

		__outs=()

		if [[ $__outline =~ ^.*\;.*\>(.*)$ ]]
		then
				local matched=${BASH_REMATCH[1]}
				trim matched
				IFS=, read -ra __outs <<<"$matched"
		fi
}

ol_setOuts() {
		local -n __outline=$1

		local -a __outs
		arg_read "$2" __outs

		if [[ $__outline =~ ^(.*\;.*\>).*$ ]]
		then
				a_reorder __outs
				
				local IFS=,
				local sig="${__outs[*]}"
				unset IFS
				
				local parts=(${BASH_REMATCH[1]} ${sig})

				__outline="${parts[*]}"
		fi
}

ol_unpack() {
		local o
		ol_read o "$1"

		local -n ___bid="$2"
		local -n ___ins="$3"
		local -n ___outs="$4"

		ol_getBid o ___bid
		ol_getIns o ___ins
		ol_getOuts o ___outs
}

ol_pack() {
		local -n ____out="$4"

		local o
		ol_create o "$1" "$2" "$3"
		ol_write o ____out
}


export __LIB_OUTLINE=1
