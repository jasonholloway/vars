#!/bin/bash
shopt -s extglob

source "${VARS_PATH:-.}/common.sh"

pts=${1:?need to pass pts}

outFile="$HOME/.vars/out"
cacheDir="$HOME/.vars/cache"

main() {
  local type block

  setupBus

  while hear type rest; do
    case "$type" in
				run)
						run $rest
            ;;
    esac

    say "@YIELD"
  done
}

run() {
		local cacheFile cacheVals
		local outline runFlags bid rawOuts blockFlags ivn vn isMultiIn v
		local -a vals=()
		local -a args=()
		local now=$(date +%s)

		IFS=$FS read -r bid _ _ rawOuts blockFlags <<< "$*"

		while hear type line; do
				case $type in
						arg) args+=("$line");;
						flags) runFlags=$line;;
						val) vals+=("$line");;
						go) break;
				esac
		done

		isCacheable=
		[[ $blockFlags =~ C ]] && isCacheable=1

		# so if the block is cacheable,
		# we want firstly to establish a conversation with the cache
		# and supply it our header of variables
		#
		# the cache will then tell us whether it has data or not
		#
		#

		if [[ $isCacheable ]]; then
				cacheVals=$(for val in "${args[@]}" "${vals[@]}"; do echo "$val"; done | sort | tr '\n' '\30')
				local hash=$(sha1sum <<< "$bid ${cacheVals}")
				cacheFile="$cacheDir/R-${hash%% *}"
		fi

		{
				runIt=1

				if [[ $isCacheable && -e "$cacheFile" ]]; then
						{
								local missed
								
								while read -r type line; do
											case "$type" in
													"t")
															if [[ $line < $now ]]; then
																	missed=1
																	break
															fi
													;;
													"f")
															:
													;;
													"v")
															if [[ "$line" != "$cacheVals" ]]; then
																	missed=1
																	break
															fi
													;;
													"")
															:
															break
													;;
											esac
								done 

								if [[ ! $missed ]]; then
										echo @fromCache
										cat
										runIt=
								fi
						} <"$cacheFile"
				fi

				if [[ $runIt ]]; then
						case "$bid" in
								get:*)
										vn="${bid##*:}"
										vn="${vn%\*}"

										for val in "${vals[@]}"; do
												read -r vvn v <<< "$val"
												if [[ $vvn == $vn ]]; then
														# decode v v
														say "out $v"
												fi
										done
								;;

								file:*)
										vn="${bid##*:}"
										vn="${vn%\*}"
										echo "TODO: Evaluate file $vn" >&2
										:
								;;

								*)
										say "@ASK files"
										say "body $bid"
										say "@YIELD"
										hear hint
										hear body
										say "@END"

										decode body body

										(
												source $VARS_PATH/helpers.sh 

												shopt -s extglob

												local argI=0
												for arg in "${args[@]}"; do
														pres+=("ARG${argI}='$arg';")
														argI=$((argI + 1))
												done

												for val in "${vals[@]}"; do
														read -r vn v <<< "$val"
														decode v v
														pres+=("$vn+=('$v');")
												done

												eval "
														[[ \$VARS_DEBUG ]] && set -x
														${pres[*]}
														set -e
														$body
														" <"$pts"
										)
								;;
						esac \
						| {
									if [[ $isCacheable ]]; then
											local -a buff=()
											local cacheFor
											local cacheTill=0

											while read -r line; do
													case "$line" in
															"@cacheTill "*)
																	read -r _ cacheTill _ <<<"$line"
																	;;

															"@cacheFor "*)
																	read -r _ cacheFor _ <<<"$line"
																	cacheTill=$((now + cacheFor))
																	;;

															*)
																	buff+=("$line")
																	echo "$line"
																	;;
													esac
											done

											{
												echo "t ${cacheTill}"
												echo "v ${cacheVals}"
												echo 
												printf "%s\n" "${buff[@]}"
											} >"$cacheFile"

									else
											while read -r line; do
														case "$line" in
																"@cache"*)
																		;;
																*)
																		echo "$line"
																		;;
														esac
											done
									fi
							}
				fi
		} \
		| {
				local fromCache=
				local -A bound=()
				local -a lines=()

				while read -r line; do
						case "$line" in
								@fromCache)
										fromCache=1
										# this should be somehow communicated back out to traces...
								;;

								@bind[[:space:]][[:word:]]*)
										read -r _ vn v <<< "$line"
										say bind "$vn" "$v"
										bound[$vn]=1
								;;

								@bindHeredoc[[:space:]][[:word:]]*)
										read -r _ vn _ <<< "$line"
										say bindHeredoc "$vn"
										bound[$vn]=1

										while read -r l; do
											if [[ $l =~ ^EOF ]];
												then break;
												else say "$l";
											fi
										done

										say "EOF"
								;;

								@set[[:space:]][[:word:]]*)
										read -r _ n v <<< "$line"
										say set "$n" "$v"
								;;

								@out*)
										read -r _  v <<< "$line"
										say out "$v"
								;;

								+([[:word:]])=*)
										vn="${line%%=*}"
										v="${line#*=}"
										say bind "$vn" "$v"
										bound[$vn]=1
								;;

								*)
										lines+=("$line")
								;;
						esac
				done
		        
				local -a outs
				outs=($rawOuts)
				out0=${outs[0]}

				if [[ ! -z $out0 && -z ${bound[$out0]} ]]; then
						if [[ $out0 =~ ^data#(.+) ]]; then
								name=${BASH_REMATCH[1]}

								say "@ASK cache"
								say "putData"
								say "$name"
								for val in "${args[@]}" "${vals[@]}"; do say "$val"; done
								say

								say newFile
								say "@YIELD"

								hear file

								for line in "${lines[@]}"; do
										echo "$line" >> "$file"
								done
								say

								say fin
								say "@YIELD"

								hear spec

								say "@END"

								say bind "$out0" "$spec"

						else
								IFS=$'\31'; say bind "$out0" "${lines[*]}"
						fi
				fi
			}

		say fin
}

main "$@"


# DO WE REALLY WANT CONSISTENT HASHING OF DATA FILE NAME???  the file
# path should sit in the normal cache till its expiry so each
# generation of the file should have a different hash even if it has
# exactly the same inputs
#
# almost like the cache header should be given to the *actual* cache
# and not the virtual files system
#
# what we really want is for the name to be part of the path, but with
# some kind of unique addition - an addition given to it by the actual
# cache entry?
#
# but even the hash deduced by the cache should have some expiry or
# ttl too
#
# every cacheing should return a unique name, formed by the cache
# mechanism itself - the actual content would be up to the cache, but
# it would be expected to be informative and consistent
# eg ${vn}.${hash}.${expiry}.${fileNum}.data
#
# cacheing is of a block, rather than of a single variable, seemingly
# the hash above encodes the block specs, the determinant source the
# vn is just the split out portion of the cacheing relating to the file
#
# 
