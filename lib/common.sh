#!/bin/bash

trim() {
		local -n __v="$1"
    __v="${__v#"${__v%%[![:space:]]*}"}"
    __v="${__v%"${__v##*[![:space:]]}"}"   
}

a_trimAll() {
		local -n __a=$1
		local i
		
		for i in ${!__a[*]}
		do trim __a[$i]
		done
}

a_has() {
		local -n __a=$1
		local val=$2
		local v

		for v in "${__a[@]}"
		do
				if [[ $v == $val ]]
				then return 0
				fi
		done

		return 1
}

export __LIB_COMMON=1
