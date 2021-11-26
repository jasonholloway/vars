#!/bin/bash

[[ $__LIB_ARRAY ]] || source ${VARS_PATH}/lib/array.sh 
[[ $__LIB_ASSOCARRAY ]] || source ${VARS_PATH}/lib/assocArray.sh 

set_init() {
		local -n _s="$1"
		_s=()
}

set_read() {
		local -n _s="$1"

		local raw
		arg_read "$2" raw

		IFS=',' read -ra _s <<<"$raw"

		local -A _A=()
		for p in "${_s[@]}"
		do
				_A[$p]=1
		done

		_s=("${!_A[@]}")
		a_reorder _s
}

set_write() {
		local -n _s="$1"
		local -n _out="$2"

		local IFS=','
		_out="${_s[*]}"
}

set_add() {
		local -n __s="$1"

		local __v
		arg_read "$2" __v

		local -A __A=()
		local __p
		for __p in "${__s[@]}"
		do
				__A+=([$__p]=1)
		done

		__A+=([$__v]=1)

		__s=("${!__A[@]}")
		a_reorder __s
}

export __LIB_SET=1
