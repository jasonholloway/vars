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


rewrite_expand() {
		local -a outlines=()
		local -A supplies=()
		local -a __roots
		local line i o out outs

		arg_read "$1" __roots

		# each root is a vn
		# and each vn can have pins on it
		# so we want to store initial root lookups
		# (that can then be changed as we walk)
		#
		# but these lookups, if they can refer to more generic suppliers,
		# must also store contexts at the same time
		# the extended outline is then really a compound link
		# pins should be compounded if they can be
		# but if they can't, then do we always split into a separate world?
		# no - id the combination is impossible, it is nil
		# differences can only be sustained by being in separate subtrees
		#
		# though we also want joins to solve duplication
		#
		# each subtree is treated separately, though in the actual running
		# inconsistencies may arise - we should catch these at runtime
		# no - inconsistencies must be allowed
		# name{name=Boris} is different from name{name=Biter}
		# different, coexistent worlds
		

		i=0
		while nosh outline_read o
		do
				outline_getOuts o outs
				for out in "${outs[@]}"; do
						supplies["$out"]+="$i "
				done
				
				outline_setRest o "v:"
				parp outline_write o

				((i++))
		done

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
