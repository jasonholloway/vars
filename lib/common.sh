#!/bin/bash

nom() {
		local str
		read -r str
		local ret=$?
		
		eval "$* \"v:$str\""

		return $ret
}

nosh() {
		local str
		read -r -d '' str
		local ret=$?
		
		eval "$* \"v:$str\""

		return $ret
}

parp() {
		local str
		eval "$* str"
		echo "$str"
}

parp_a() {
		local -a r
		eval "$* r"
		echo "${r[*]}"
}

parp_A() {
		local -A r
		eval "$* r"
		parp A_write r
}

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

export __LIB_COMMON=1
