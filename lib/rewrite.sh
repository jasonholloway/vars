#!/bin/bash

[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh 
[[ $__LIB_VN ]] || source lib/vn.sh
[[ $__LIB_OUTLINE ]] || source lib/outline.sh 
[[ $__LIB_SMAP ]] || source lib/smap.sh
[[ $__LIB_LINK ]] || source lib/link.sh

ols_ingest() {
		declare -ga outlines=()
		declare -gA supplies=()
		declare -gA links=()

		local o t out outs raw i l
		local i=0

		while nom ol_read o
		do ol_write o outlines[${#outlines[@]}]
		done

		for ((i=0; i<${#outlines[@]}; i++))
		do
				ol_read o n:outlines[$i]
				ol_getOuts o outs

				for t in "${outs[@]}"
				do
						link_init l
						link_addSupplier l v:$i
						link_write l links[$t]
				done
		done
}

ols_write() {
		local -n __out="$1"
		local IFS=$'\n'
		__out="${outlines[*]}"
}



ols_formLinks() {

		while nom ol_read o
		do
				ol_getOuts o outs

				for out in "${outs[@]}"; do
						supplies["$out"]+="$i "
				done

				ol_write o outlines[${#outlines[@]}]

				((i++))
		done




		
		:
}






# before we specialize,ifwe have the exploredinnards at hand, we can efficiently filter up front
#
#
#

ols_fillMasks() {
		local -a targets=()
		arg_read "$1" targets

		local mask
		smap_init mask

		local t
		for t in "${targets[@]}"
		do ols_rewrite_visit "$t"
		done
}



ols_fillMasks_visit() {
		local target="$1"

		#here need to bind generically too
		local -a found=(${supplies[$target]})

		# ths is a bit of a problem - we shouldn't be doing this twice, you'd think
		# like we want to walk through once and work out some specializable links
		# the links would then have masks filled out

		# and then the links would be used to specialise
		# so - first visit would create links 
		# second visit would summon masks per link
		# third visit would specialize outline to please links

		# instead of changing outlines directly, with 'rest' attached per-block
		# we instead deal with links per target
		# masks are per target; pins are also per target
		#
		
		# maybe even the ordering of blocks, the actual order of execution
		# could be done via the links graph
		# though then again we're sacrificing tesstability (unless we tested dumps of links)
		# the link table would be output - not the worst idea actually
		# and we'd want a link datatype
		# an assoc array of links would be keyed by target
		# starting with just found target names
		# 
		#
		#

		local f ol ins inp vn n
		for f in "${found[@]}"
		do
				ol_read ol n:outlines[$f]
				ol_getIns ol ins

				local -A maskAc=()
				for inp in "${ins[@]}"
				do
						vn_read vn n:inp
						vn_getName vn n
						maskAc+=([$n]=1)
				done

				smap_pushA mask maskAc


				parp smap_write mask >&2
		done
}




# summons outline indices
ols_summonSupplier() {
		local t="$1"
		local -n _found="$2"
		local -n _mask="$3"

		_found=(${supplies[$t]})

		# degrade target here to find generic

		local f
		for f in "${_found[@]}"
		do
				local ol
				ol_read ol "n:outlines[$f]"
				ols_summonMask ol _mask
		done
}

ols_summonMask() {
		local -n _ol=$1
		local -n __mask=$2

		local -a ins=()
		ol_getIns _ol ins

		local inp
		for inp in "${ins[@]}"
		do
				local vn n
				vn_read vn "n:inp"
				vn_getName vn n
				__mask+=($n)

				ols_summonSupplier n:inp _ __mask
		done
}

# summoning _specializes_
# but should also return plumbed masks
# but if it does that, then it's no longer simple
#
# maybe a set of lazy methods...
# ols_summonMask would be in a coroutine relationship with summonSupplier
# to know a mask, we have to crawl the tree
# which requires summoning a supplier
#
# 
#
#






ols_plumb() {
		local -a knowns
		smap_init knowns

		ols_plumb_visit "$1"

		IFS=$'\n'; echo "${outlines[*]}"
}

# uses outlines:a, supplies:a, pins:smap
ols_plumb_visit() {
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

								A_write rest restRaw '+' '='

						ol_pack n:bid na:inps na:outs n:restRaw newOutline

						if [[ $newOutline != "${outlines[$i]}" ]]
						then outlines+=("$newOutline")
						fi

						ols_expand_visit "a:${inps[*]}"
				done

				smap_pop pins _
		done
}



ols_propagatePins() {
		local -a pins
		smap_init pins

		ols_propagatePins_visit "$1"

		IFS=$'\n'; echo "${outlines[*]}"
}

# uses outlines:a, supplies:a, pins:smap
ols_propagatePins_visit() {
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

								A_write rest restRaw '+' '='

						ol_pack n:bid na:inps na:outs n:restRaw newOutline

						if [[ $newOutline != "${outlines[$i]}" ]]
						then outlines+=("$newOutline")
						fi

						ols_propagatePins_visit "a:${inps[*]}"
				done

				smap_pop pins _
		done
}



# only pins that find an injection should survive our cull
# work bottom up culling from contexts 
# this requires storage on the outlines

ols_applyPins() {

		# in applying, to cull at same time,
		# we need to crawl tree instead of enumerating
		# visit bottom-up, collecting a backwards var context
		#
		#
		#

		
		local -a pins
		smap_init pins

		ols_applyPins_visit "$1"

		IFS=$'\n'; echo "${outlines[*]}"
}

ols_applyPins_visit() {
		:
}


export __LIB_REWRITE=1
