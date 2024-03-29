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

    say "@END"
  done
}

run() {
	local cacheFile
	local outline runFlags blockFlags ivn vn isMultiIn v
	local -a vals=()

	IFS=$FS read -r bid _ _ _ blockFlags <<< "$*"

	while hear type line; do
		case $type in
			flags) runFlags=$line;;
			val) vals+=("$line");;
			go) break;
		esac
	done

	isCacheable=
	[[ $blockFlags =~ C ]] && isCacheable=1

	if [[ $isCacheable ]]; then
		local hash=$(sha1sum <<< "$bid ${vals[*]}")
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
					vn="${vn%\*}"

					for val in "${vals[@]}"; do
					read -r vvn v <<< "$val"
					if [[ $vvn == $vn ]]; then
						decode v v
						say "out $v"
					fi
					done
				;;
				*)
					say '@ASK files'
					say "body $bid"
					hear hint
					hear body
					say '@END'

					decode body body

					USE_PTY=1

					# hints should tell us about run options
					# eg vim and less are full pty
					# when enabled, we wouldn't capture stdout - does this mean it should be opt in, the inverse? I think so: 'stdout_cmd' should be the hint
					# todo: needed to support vim and less

					# ideally, we'd request a pane, with full command string, and be given back
					# input and output fifos (TODO)
					# which we'd then have to nicely close

					(
						echo "@running $BASHPID"

						pres+=("source $VARS_PATH/helpers.sh;")
						pres+=("shopt -s extglob;")
						
						[[ $VARS_DEBUG ]] && pres+=("set -x;")

						for val in "${vals[@]}"; do
							read -r vn v <<< "$val"
							decode v v
							pres+=("$vn+=('$v');")
						done

						body="${pres[*]} $body"

						if [[ $USE_PTY ]]; then
							fifoOut="/tmp/vars-run-out.fifo"
							[[ ! -p "$fifoOut" ]] && mkfifo "$fifoOut"

							cat $fifoOut &
							pid=$!

							# the output fifo should be written to directly by helpers
							# leaving stdout simply going to window
							# stderr could be captured into the log however

							tmux -L${VARS_TMUX_SOCKET} splitw -h /bin/bash -c "{ ${body%;}
} >$fifoOut"

							wait "$pid"
						else
							eval "$body"
						fi

						echo "@fin"
					) &

					(
						echo "@listening $BASHPID"
						hear _ # expected to be 'cancel'
						echo "@fin"
					) &

					wait
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
		local -a pids=()
		
		while read -r line; do
			case "$line" in
				@listening*)
					pids+=(${line#* })
				;;

				@running*)
					pids+=(${line#* })
				;;

				@fin)
					break
				;;
				
				@fromCache)
					fromCache=1
					# this should be somehow communicated back out to traces...
				;;

				@bind[[:space:]][[:word:]]*)
					read -r _ vn v <<< "$line"
					say bind "$vn" "$v"
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
				;;

				*)
					say out "$line"
				;;
			esac
		done

		for pid in ${pids[@]}; do pkill -INT -P $pid; done

		say fin
	}
	# | {
	#     >"$outFile"
	
	# 	if [[ ${runFlags[*]} =~ "T" ]]; then
	# 	while read -r line; do
	# 		say out "$line"
	# 		echo "$line" >>"$outFile"
	# 	done
	# 	fi
	# 	}


	# say fin
}

main "$@"
