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

		local ___r=${i#*:}
		
		case ${i%%:*} in
				v) __o=$___r
				;;
				n) local -n __v=$___r
					 __o=${__v}
				;;
				na)local -n __v=$___r
					 local p
					 for p in "${__v[@]}"
					 do __o+=("$p")
					 done
				;;
				a) __o=($___r)
				;;
				A) __o=($___r)
				;;
		esac
}

lg() {
		echo "$*" >&2
}

export __LIB_COMMON=1
