#!/bin/bash

[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh 
[[ $__LIB_VN ]] || source lib/vn.sh
[[ $__LIB_OUTLINE ]] || source lib/outline.sh 
[[ $__LIB_SMAP ]] || source lib/smap.sh

# newly specialized outlines should be 
# cloned from existing outlines as if from prototypes
# instead of altering existing ones
# this means updating the supplies
#


ols_fitToPins() {
		:
}

ols_fitToPins_visit() {
		:
}



rewrite_expand() {
		local -a outlines=()
		local -A supplies=()
		local i o out outs inps inp raw
		local t

		i=0
		while nom ol_read o
		do
				ol_getOuts o outs

				for out in "${outs[@]}"; do
						supplies["$out"]+="$i "
				done

				# todo: below should always emit rest canonically!!!
				ol_write o outlines[${#outlines[@]}]

				((i++))
		done

		local -a pins
		smap_init pins

		rewrite_expand_visit "$1"

		IFS=$'\n'; echo "${outlines[*]}"
}

# only pins that find an injection should survive our cull
# work bottom up culling from contexts 
# this requires storage on the outlines
# 
# TODO outlines should be normalized at the top



# uses outlines:a, supplies:a, pins:smap
rewrite_expand_visit() {
		local -a ts=()
		arg_read "$1" ts

		local t i bid inps outs rest newOutline
		local -a inps=()
		local -a outs=()

		for t in "${ts[@]}"
		do
				local -a bs=(${supplies[$t]})
				lg T $t "${bs[*]}"

				local -A newPins=()

				# decompose and retry if failed
				if [[ ${#bs[@]} == 0 ]]
				then
						local vn
						vn_read vn "n:t"

						vn_getPins vn newPins

						vn_getName vn t

						bs=(${supplies[$t]})

						lg T $t "${bs[*]}"
				fi

				smap_pushA pins newPins
				
				for i in "${bs[@]}"
				do
						[[ -z $i ]] && continue
						lg O $i ${outlines[$i]}
						
						ol_unpack n:outlines[$i] bid inps outs restRaw

						local -A rest=()
						A_read rest n:restRaw

						local -A currPins=()
						smap_peekA pins currPins
						A_merge rest currPins

						rewrite_expand_visit "a:${inps[*]}"

						A_write rest restRaw '+' '='
						ol_pack n:bid na:inps na:outs n:restRaw newOutline

						# below won't work properly until we get rid of or normalize 'rest'
						if [[ $newOutline != ${outlines[$i]} ]]
						then
								outlines+=("$newOutline")
						fi
				done

				smap_pop pins _
		done
}


supplier_lookup() {
		local vn="$1"
		local -n __r=$2
		local i

		__r=()

		for i in ${supplies[$vn]}
		do __r+=(outlines[$i])
		done
}

export __LIB_REWRITE=1
