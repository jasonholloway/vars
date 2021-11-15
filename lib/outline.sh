#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh
[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh

ol_create() {
		local -n ___o=$1

		___o=("" "" "" "")

		[[ $2 ]] && ol_setBid ___o "$2"
		[[ $3 ]] && ol_setIns ___o "$3"
		[[ $4 ]] && ol_setOuts ___o "$4"
		[[ $5 ]] && ol_setRest ___o "$5"
}

ol_read() {
		local -n __o=$1
		
		local raw
		arg_read "$2" raw

		local bid rawIns
		IFS=$';' read bid raw <<<"$raw"
		IFS='>' read rawIns raw <<<"$raw"

		local rawOuts rest
		if [[ $raw =~ (.*)\{([^\{]*)\}$ ]]
		then
				rawOuts=${BASH_REMATCH[1]}
				rest=${BASH_REMATCH[2]}
		else
				rawOuts=$raw
		fi

		trim bid
		trim rawIns
		trim rawOuts
		trim rest

		__o=("$bid" "$rawIns" "$rawOuts" "$rest")
}

ol_write() {
		local -n __o=$1
		local -n __out=$2
		__out="${__o[0]}; ${__o[1]} > ${__o[2]} {${__o[3]}}"
		__out="${__out//  / }"
}

ol_getBid() {
		local -n __o=$1
		local -n __bid=$2
		__bid=${__o[0]}
}

ol_setBid() {
		local -n ____o=$1
		arg_read "$2" ____o[0]
}

ol_getRest() {
		local -n __o=$1
		local -n __rest=$2
		__rest=${__o[3]}
}

ol_setRest() {
		local -n ____o=$1
		arg_read "$2" ____o[3]
}

# TODO ins and outs to be stored as formatted strings

ol_getIns() {
		local -n __o=$1
		local -n __ins=$2
		IFS=, read -ra __ins <<<"${__o[1]}"
}

ol_setIns() {
		local -n __o=$1

		local -a __ins=()
		arg_read "$2" __ins

		local IFS=,
		__o[1]="${__ins[*]}"
}

ol_getOuts() {
		local -n __o=$1
		local -n __outs=$2
		IFS=, read -ra __outs <<<"${__o[2]}"
}

ol_setOuts() {
		local -n __o=$1

		local -a __outs=()
		arg_read "$2" __outs

		local IFS=,
		__o[2]="${__outs[*]}"
}

ol_unpack() {
		local o
		ol_read o "$1"

		local -n ___bid="$2"
		local -n ___ins="$3"
		local -n ___outs="$4"
		local -n ___rest="$5"

		ol_getBid o ___bid
		ol_getIns o ___ins
		ol_getOuts o ___outs
		ol_getRest o ___rest
}

ol_pack() {
		local -n ____out="$5"

		local o
		ol_create o "$1" "$2" "$3" "$4"
		ol_write o ____out
}


export __LIB_OUTLINE=1
