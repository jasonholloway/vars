#!/bin/bash
shopt -s extglob

source "${VARS_PATH:-.}/common.sh"

pts=${1:?need to pass pts}

cacheDir="$HOME/.vars/cache"
dataDir="$cacheDir/data"

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
		
		local -a outs
		outs=(${rawOuts//>/}) #erasing the premod here is a hack: means
													#that > has no real effect, just looks nice
		out0=${outs[0]}
		# echo "OUT: $rawOuts" >&2

		local varFromOut dataFromOut
		if [[ ${#outs[@]} == 1 ]]; then
				varFromOut=${outs[0]}
		fi

		local -A dataOuts=()
		for o in "${outs[@]}"; do
					if [[ "$o" =~ \. ]]; then
							o=${o//>/}
							dataOuts[${o}]="${o}"
							# dataOuts[$o]="${BASH_REMATCH[1]}"
					fi
		done

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

										# no more comms with cache needed
										say "@END"
										;;
								miss)
										hear cacheToken

										say "openSinks $cacheToken"

										for d in "${!dataOuts[@]}"; do
													read name _ <<< "${dataOuts[$d]}"
													say "$name"
													say "@YIELD"

													hear sink
													dataOuts["$d"]="$name $sink"

													if [[ $d == $varFromOut ]]; then
															dataFromOut="$sink"
													fi
										done

										say
										;;
						esac
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

													if [[ $vn =~ \. ]]; then
															vn=${vn//./_}

															if [[ $v =~ ^file\;([^\;]+) ]]; then
																	v="${BASH_REMATCH[1]@P}"
															fi
													fi

													pres+=("$vn+=('$v');")
										done

										for d in "${dataOuts[@]}"; do
													read name sink _ <<< "$d"
													pres+=("${name//./_}=${sink}");
										done

										eval "
												[[ \$VARS_DEBUG > 1 ]] && set -x
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
																	if [[ $dataFromOut ]]; then
																			echo "$line" >>$dataFromOut
																	else
																			#unsure if we always want to both buffer and echo the line below?
																			#does it depend on whether we're doing varFromOut???
																			buff+=("$line")
																			echo "$line"
																	fi
																	;;
													esac
										done

										if [[ ! $failed ]]; then
												local -a boundData=()

												say "closeSinks $cacheToken"
												say "@YIELD"
												while hear name spec && [[ ! -z $name ]]; do
															line="@bind ${name} ${spec}"
															buff+=("$line")
															boundData+=("$line")
												done

												say "put $cacheToken"
												say "OUT"
												for line in "${buff[@]}"; do
															say "$line"
															echo "$line"
												done
												say
										fi

										say "@END"

										# must be echoed after cache conversation
										for line in "${boundData[@]}"; do
													echo "$line"
										done
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

		if [[ $failed ]]; then
				IFS=$'\36'; say fail "${lines[*]}"

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
				IFS=$'\36'; say bind "${out0}" "${lines[*]}"

				# fi
		fi
}

		say fin
}

main "$@"

