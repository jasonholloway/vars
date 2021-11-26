#!/bin/bash

[[ $__LIB_COMMON ]] || source ${VARS_PATH}/lib/common.sh
[[ $__LIB_ASSOCARRAY ]] || source ${VARS_PATH}/lib/assocArray.sh

vn_read() {
		local -n __vn=$1
		local v; arg_read "$2" v

		__vn=()

		if [[ $v =~ ^([a-zA-Z0-9]+)(\{(.*)\})?$ ]]
		then
				local n=${BASH_REMATCH[1]}
				local rest=${BASH_REMATCH[3]}
				__vn=("$n" "$rest")
		fi
}

vn_write() {
		local -n __vn=$1
		local -n __out=$2

		if [[ ${__vn[1]} ]]
		then
			__out="${__vn[0]}{${__vn[1]}}"
		else
			__out="${__vn[0]}"
		fi
}

vn_getName() {
		local -n __vn=$1
		local -n __n=$2
		__n=${__vn[0]}
}

vn_getPins() {
		local -n __vn=$1
		local -n __pins=$2
		A_read __pins "v:${vn[1]}" '+' '='
}

vn_setPins() {
		local -n __vn=$1
		local -n __pins=$2
		A_write_ordered __pins __vn[1] '+' '='
}

export __LIB_VN=1
