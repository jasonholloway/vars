#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh

a_read() {
		local -n __a=$1
		local v
		arg_read "$2" v
		__a=($v)
}

a_write() {
		local -n __a=$1
		local -n __out=$2
		__out="${__a[*]}"
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

a_reverse() {
		local -n __a=$1

		local h=${#__a[*]}
		[[ $h -gt 0 ]] && ((h--))

		
		local l=${2:-0}
		local tmp

		while [[ $h > $l ]]
		do
				tmp=${__a[$l]}
				__a[$l]=${__a[$h]}
				__a[$h]=$tmp

				((h--))
				((l++))
		done
}

a_debug() {
		local -n __a=$1
		local p

		for p in "${__a[@]}"
		do echo -n "_${p}_ "
		done

		echo
}

export __LIB_ARRAY=1
