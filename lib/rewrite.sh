#!/bin/bash

[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh 
[[ $__LIB_VN ]] || source lib/vn.sh
[[ $__LIB_OUTLINE ]] || source lib/outline.sh 
[[ $__LIB_SMAP ]] || source lib/smap.sh

rewrite_expand() {
		local -a outlines=()
		local -A supplies=()
		local -a __roots
		local i o out outs

		arg_read "$1" __roots

		i=0
		while nom outline_read o
		do
				outline_getOuts o outs

				for out in "${outs[@]}"; do
						supplies["$out"]+="$i "
				done

				((i++))
		done

		local -a pins
		smap_init pins

		local -a targets
		smap_init targets

		# copying roots into targets
		# means ingesting array

		# copy roots into targets
		# copy global pins into pins

		# now we visit all the targets
		# on first pass, each visited var gets given a pin context
		# and each discovered pin context gets added to the visit context

		# as we crawl, we have two contexts
		# we have targets
		# we have pinnings
		
		

				# outline_setRest o "v:"

		A_printNice supplies >&2
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
