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
		local outline runFlags bid rawOuts blockFlags ivn vn isMultiIn v cacheToken
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

		# TODO
		# for all data out vars, we need to summon sink files from the cache
		# and inject the locations of these into the block
		#
		# the cache therefore needs asynchronous confirmation that each
		# file has been written to, before it will yield back file specs to be bound
		#
		# so before running, we summon data sinks
		# and then we run the block
		# and then we confirm that we have finished with each of them by name
		# which allows us to bind them
		        
		local -a outs
		outs=($rawOuts)
		out0=${outs[0]}
		# echo "OUT: $rawOuts" >&2

		cacheToken=

		{
				runIt=1

				if [[ $blockFlags =~ C ]]; then
						say "@ASK cache"
						say "peek"
						say "$bid"
						for val in "${args[@]}" "${vals[@]}"; do
								if [[ ! $val =~ ^_ ]]; then say "$val"; fi
						done
						say
						say "@YIELD"

						hear line

						case "$line" in
								hit)
										runIt=
										while hear line && [[ ! -z "$line" ]]; do
													echo "$line"
										done
										;;
								miss)
										hear cacheToken

										#todo openSinks here
										#
										#
										#

										
										;;
						esac
						say "@END" #do I need to end this here? I think not... it will be resumed after the file stuff
				fi

				if [[ $runIt ]]; then
						{
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

												v="${v//\'/\'\\\'\'}"

												pres+=("$vn+=('$v');")
										done

										eval "
												[[ \$VARS_DEBUG ]] && set -x
												${pres[*]}
												set -e
												$body
												" <"$pts" \
										|| echo "@fail"
								)
						} \
						| {
								  if [[ ! -z $cacheToken ]]; then
											local -a buff=()
											local cacheFor
											local cacheTill=0
											local failed

											while read -r line; do
													case "$line" in
															"@cacheTill "*)
																	read -r _ cacheTill _ <<<"$line"
																	;;

															"@cacheFor "*)
																	read -r _ cacheFor _ <<<"$line"
																	cacheTill=$((now + cacheFor))
																	;;

															"@fail")
																	failed=1
																	echo "$line"
																	;;

															*)
																	buff+=("$line")
																	echo "$line"
																	;;
													esac
											done

											#todo need to intercept binds to populate files here?
											#the line buffer should be used

											if [[ ! $failed ]]; then
												say "@ASK cache"
												say "put $cacheToken"

												say "OUT"
												for line in "${buff[@]}"; do
															say "$line"
															echo "$line"
												done
												say

												say "@END"
											fi
									else
											while read -r line; do
														case "$line" in
																"@cache"*) ;;
																*) echo "$line";;
														esac
											done
									fi
							}
				fi
		} \
		| {
				local -A bound=()
				local -a lines=()
				local failed

				while read -r line; do
						case "$line" in
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

								@out*)
										read -r _  v <<< "$line"
										say out "$v"
								;;

								@fail)
										failed=1
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

				# so we need to know the capturing scheme up front - ie, do we need to capture output lines for file purposes?
				# well, if we know we're capturing into a file, then we should be able to stream directly into the cache
				#
				# if the first output is a data output (possibly with a flag on it as well?
				# then all encountered outputs are sent to the cache directly 
				# well they're not even written to the cache, they're to be written into the file mechanism
				#
				#

				if [[ $failed ]]; then
						for line in "${lines[@]}"; do
									say out "$line"
						done

				elif [[ ! -z $out0 && -z ${bound[$out0]} ]]; then

						# if [[ $out0 =~ ^data#(.+) ]]; then
						# 		name=${BASH_REMATCH[1]}

						# 		say "@ASK cache"
						# 		say "putData"
						# 		say "$name"
						# 		for val in "${args[@]}" "${vals[@]}"; do say "$val"; done
						# 		say

						# 		say newFile
						# 		say "@YIELD"

						# 		hear file

						# 		for line in "${lines[@]}"; do
						# 				echo "$line" >> "$file"
						# 		done
						# 		say

						# 		say fin
						# 		say "@YIELD"

						# 		hear spec

						# 		say "@END"

						# 		say bind "$out0" "$spec"

						# else

						    #nb we 'encode' with \36; but if we wanted to communicate choice of vals instead, we'd use \31
						    #there should be some kind of marker on the out var to choose between behaviours
								IFS=$'\36'; say bind "$out0" "${lines[*]}"

						# fi
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
