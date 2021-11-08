#!/bin/bash

nosh() {
		local str
		read -r str
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

a_reorder() {
		local -n __r=$1
		local ok last curr

		while true
		do
			ok=1
			last=

			for i in "${!__r[@]}"
			do
					curr=${__r[$i]}

					if [[ $curr < $last ]]
					then
							ok=
							__r[((i-1))]=$curr
							__r[$i]=$last
					else
							last=$curr
					fi
			done

			[[ $ok ]] && break
		done
}

export __LIB_COMMON=1
