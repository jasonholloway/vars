#!/bin/bash

[[ $__LIB_ARRAY ]] || source ${VARS_PATH}/lib/array.sh 
[[ $__LIB_ASSOCARRAY ]] || source ${VARS_PATH}/lib/assocArray.sh 
[[ $__LIB_SET ]] || source ${VARS_PATH}/lib/set.sh
[[ $__LIB_VN ]] || source ${VARS_PATH}/lib/vn.sh
[[ $__LIB_SMAP ]] || source ${VARS_PATH}/lib/smap.sh

link_init() {
		local -n _l="$1"
		_l=()
}

link_read() {
		local -n _l="$1"
		
    local raw
    arg_read "$2" raw

		IFS=';' read -ra _l <<<"$raw" 
}

link_write() {
		local -n _l="$1"
		local -n _out="$2"

		local IFS=';'
		_out="${_l[*]}"
}

link_addSupplier() {
		local -n _l="$1"

		local -a s=()
		set_read s n:_l[0] 
		set_add s "$2"
		set_write s _l[0]
}

export __LIB_LINK=1
