#!/bin/bash

[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh 
[[ $__LIB_VN ]] || source lib/vn.sh
[[ $__LIB_OUTLINE ]] || source lib/outline.sh 
[[ $__LIB_SMAP ]] || source lib/smap.sh

ols_read() {
		:
}

rewrite_expand() {
		local -a outlines=()
		local -A supplies=()
		local i o out outs inps inp
		local t

		i=0
		while nom ol_read o
		do
				ol_getOuts o outs

				for out in "${outs[@]}"; do
						supplies["$out"]+="$i "
				done

				outlines+=("$o")

				((i++))
		done

		local -a pins
		smap_init pins

		rewrite_expand_visit "$1"

		# local -A ts
		# smap_peekA targets ts

		# for t in "${!ts[@]}"
		# do
		# 		lg T $t ${outlines[$s]}

		# 		for i in "${supplies[$t]}"
		# 		do
		# 				o=${outlines[$i]}
		# 				ol_getIns o inps

		# 				#...
						
		# 				ol_setIns o n:inps
		# 				ol_setRest o v:
						
		# 				outlines[$i]=$o
						
		# 				lg $i
		# 				:
		# 		done
		# done

		# now we visit all the targets
		# on first pass, each visited var gets given a pin context
		# and each discovered pin context gets added to the visit context

		# as we crawl, we have two contexts
		# we have targets
		# we have pinnings

		# ol_setRest o "v:"

		# A_printNice supplies >&2

		IFS=$'\n'; echo "${outlines[*]}"
}

# uses outlines:a, supplies:a, pins:smap targets:smap
rewrite_expand_visit() {
		local -a ts
		arg_read "$1" ts

		local -A ps
		smap_peekA pins ps

		local t i bid inps outs rest
		local -a inps=()
		local -a outs=()

		for t in "${ts[@]}"
		do
				lg T $t
				
				local -a bs=(${supplies[$t]})

				# decompose and retry if failed
				if [[ ${#bs[@]} == 0 ]]
				then
						local vn vnPins
						vn_read vn n:t
						vn_getPins vn vnPins
						vn_getName vn t
						bs=(${supplies[$t]})

						# todo: need to transfer pins to ambience
				fi

				# TODO
				# use rest on outlines again as freeform map
				
				for i in "${bs[@]}"
				do
						[[ -z $i ]] && continue
						lg B $i ${outlines[$i]}
						
						ol_unpack n:outlines[$i] bid inps outs rest

						rewrite_expand_visit "a:${inps[*]}"
						
						# to visit inwards requires...
						# fresh targets
						# targets are different per block

						ol_pack n:bid n:inps n:outs n:rest outlines[$i]
				done
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

#!TODO!!!
# pins must be canonically organised...
# so must be written with ordering
#!!!!!!!!


export __LIB_REWRITE=1
