#!/bin/bash

[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh 
[[ $__LIB_VN ]] || source lib/vn.sh
[[ $__LIB_OUTLINE ]] || source lib/outline.sh 

# in fact no we don't
# we need to gather all into a nice tree
# then walk it rewriting it
#
# each outline 
#
#

a_copy() {
		local -n __a=$1
		local -n __b=$2
		local v i

		i=0
		for v in "${__a[@]}"
		do __b[$i]=$v; ((i++))
		done
}




rewrite_expand() {
		local -a outlines=()
		local -A supplies=()
		local -a __roots
		local -a targets
		local i o out outs

		arg_read "$1" __roots

		i=0
		while nosh outline_read o
		do
				outline_getOuts o outs

				for out in "${outs[@]}"; do
						supplies["$out"]+="$i "
				done

				((i++))
		done

		local -A context=()

		a_copy __roots targets

		# now we visit all the targets
		# we start with an empty pin context
		# on first pass, each visited var gets given a pin context
		# and each discovered pin context gets added to the visit context

		# look at stackMap!!!!!!
		

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
