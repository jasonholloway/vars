#!/bin/bash

trim() {
		local -n __v="$1"
    __v="${__v#"${__v%%[![:space:]]*}"}"
    __v="${__v%"${__v##*[![:space:]]}"}"   
}

arg_read() {
		local i=$1
		local -n __o=$2

		local __r=${i#*:}
		
		case ${i%%:*} in
				v) __o=$__r
				;;
				n) local -n __v=$__r
					 __o=${__v}
				;;
				a) __o=($__r)
				;;
		esac
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
		local __v

		for __v in "${__a[@]}"
		do
				if [[ $__v == "$val" ]]
				then return 0
				fi
		done

		return 1
}

export __LIB_COMMON=1
