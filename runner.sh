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
		local cacheFile
		local runFlags blockFlags

		IFS=$'\031' read -r runFlags assignBinds outline <<< "$*"
		IFS=';' read -r bid _ _ blockFlags <<< "$outline"

		isCacheable=
		[[ $blockFlags =~ C ]] && isCacheable=1

		if [[ $isCacheable ]]; then
				local hash=$(echo "$bid $assignBinds" | sha1sum)
				cacheFile="$cacheDir/R-${hash%% *}"
		fi

		{
				runIt=1
				if [[ $isCacheable && -e $cacheFile ]]; then
						{
								read -r line
								if [[ $line > $now ]]; then
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

										(
												eval "$assignBinds"
												echo @out ${boundIns[$vn]}
										)
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
												eval "$assignBinds"
												for n in ${!boundIns[*]}; do
														export "$n=${boundIns[$n]}"
												done

												source $VARS_PATH/helpers.sh 

												eval "$body" <"$pts"
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

											echo $cacheTill >>"$cacheFile"
											printf "%s\n" "${buff[@]}" >>"$cacheFile"

									else
											while read -r line; do echo "$line"; done
									fi
							}
				fi
		} \
		| {
				local fromCache=
				while read -r line; do
						case "$line" in
								@fromCache)
										fromCache=1
										# this should be somehow communicated back out to traces...
								;;

								@bind[[:space:]][[:word:]]*)
										read -r _ vn v <<< "$line"
										say bind $vn $v
								;;

								@set[[:space:]][[:word:]]*)
										read -r _ n v <<< "$line"
										say set $n $v
								;;

								@out*)
										read -r _  v <<< "$line"
										echo $v
								;;

								+([[:word:]])=*)
										vn=${line%%=*}
										v=${line#*=}
										say bind $vn $v
								;;

								*)
										echo $line
								;;
						esac
				done
			} \
		| {
		    >"$outFile"
		
				if [[ ${runFlags[*]} =~ "T" ]]; then
						while read -r line; do
								say out "$line"
								echo "$line" >>"$outFile"
						done
				fi
			}

		say fin
}

main "$@"
