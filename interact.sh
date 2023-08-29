#!/bin/bash
: ${VARS_PATH:?VARS_PATH must be set!}

source "${VARS_PATH:-.}/common.sh"

fifoIn=$1
fifoOut=$2
contextFile=$3

fzy="$VARS_PATH/fzy/fzy"

colBindName='\033[0;36m'
colBindValue='\033[0;35m'
colGood='\033[0;32m'
colBad='\033[0;31m'
colNormal='\033[0m'
colDim='\e[38;5;240m'
colDimmest='\e[38;5;236m'

cmdFifo="/tmp/vars-cmds.fifo"
[[ ! -p "$cmdFifo" ]] && mkfifo "$cmdFifo"

uiFifo="/tmp/vars-ui.fifo"
[[ ! -p "$uiFifo" ]] && mkfifo "$uiFifo"

main() {
	declare -a actorPids=()

	receiverActor &
	actorPids+=($!)

	controllerActor &
	actorPids+=($!)

	uiActor
}

receiverActor() {
	while read cmd line; do
		lg "re: $cmd $line"
		case "$cmd" in
			*)
				echo "$cmd $line" >&7
				;;
		esac
	done <$fifoIn 7>$cmdFifo 8>$uiFifo
}

controllerActor() {
	local -A maskVars=()
	local -A pids=()
	
	while read cmd line; do
		lg "co: $cmd $line"
		case "$cmd" in
			defer)
				read seconds cmd2 <<< "$line"
				sleep $seconds
				echo "$cmd2" >&7
				;;

			pid)
				read cmd2 name pid <<< "$line"
				case "$cmd2" in
					add)
						pids[$name]="$pid ${pids[$name]}"
						;;
					remove)
						pids[$name]=${pids[$name]//$pid/}
						;;
					"kill")
						for p in ${pids[$name]}; do kill -INT $p; done
						pids[$name]=""
						;;
				esac
				;;

			out)
				echo "$line" >> ${VARS_OUT_FILE}
				echo "showOut $line" >&8
				;;

			bound)
				read src vn v <<< "$line"
				maskVars[$vn]=1

				echo "pid kill dredge:$vn" >&7

				if [[ $vn =~ (^_)|([pP]ass)|([sS]ecret)|([pP]wd) ]]; then
					v='****'
				else
					sed -i "1i$vn=${v//$'\60'/$'\30'}" $contextFile 
				fi

				echo "showBound $src $vn $v" >&8
				;;

			suggest)
				read vn v <<< "$line"
				# cancel run here ??? todo
				say "suggest $vn $v"
				;;

			pin)
				read -r key val <<< "$line"
				$VARS_PATH/context.sh pin "${key}=${val}" &> /dev/null
				echo "showPin $key $val" >&8
				;;

			warn)
				echo "showWarning $line" >&8
				;;

			error)
				read line
				echo "$line" >&2 # could be sent to UI
				exit 1
				;;
			
			fin)
				for p in ${pids[waiting]}; do kill $p 2>/dev/null; done
				say "@END"
				echo "fin" >&8
				break
				;;

			pick)
				echo "pick $line" >&8
				;;

			ask)
				echo "dredge $line" >&8
				;;

			running)
				currentBlock="$line"
				# todo switch mode when target block running
				# or - each block should announce itself with number, which will then contextualise all future outs
				;;

			summoning)
				vn=$line
				(
					sleep 0.5
					echo "tryDredge $vn" >&7
				) &
				echo "pid add waiting $!" >&7
				;;

			tryDredge)
				vn=$line
				if [[ ! ${maskVars[$vn]} ]]; then
					echo "dredge $vn" >&8
				fi
				;;
		esac
	done <$cmdFifo 6>$fifoOut 7>$cmdFifo 8>$uiFifo 
}

uiActor() {
	{
			# TODO fzy needs wrapping with pty0 and pty1
			# what we really want here is our own _pty_ device
			# which we can use as STDIN
			# this is what io.pl should provide us with
			# instead of the fifos
			# tho ptyize should be making it seem to be a nice tty for our command
			#
			# we just wanna say, give me a pty device please
			# and io.pl should give us one
			# and we are responsible for closing it nicely
			
		# fzy="$VARS_PATH/ptyize -r -0$pty0 -1$pty1 $fzy"

		while read type line; do
			lg "ui: $type $line"
			case "$type" in

			# targets)
			# 		for src in $line; do
			# 				IFS='|' read path index <<< "$src"
			# 				shortPath=$(realpath --relative-to=$PWD $path) >&2
			# 				src=${shortPath}$([[ $index ]] && echo "|$index")

			# 				echo -e "${colDim}Running ${src}${colNormal}" >&2
			# 		done
			# 		;;

			showBound)
					read -r src key val <<< "$line"

					[[ ! $quietMode ]] && {
							IFS='|' read path index <<< "$src"
							shortPath=$(realpath --relative-to=$PWD $path) >&2
							src=${shortPath}$([[ $index ]] && echo ":$index")

							case "$src" in
									cache*) key="\`$key";;
									pin*) key="!$key";;
							esac

							[[ ${#val} -gt 80 ]] && { val="${val::80}..."; }
							echo -e "${colBindName}${key}=${colBindValue}${val} ${colDimmest}v://${src}${colNormal}" >&2
					}
					;;

			showOut)
					if [[ $quietMode ]]; then
							echo -n "$line"
					else 
							echo "$line"
					fi
					;;

			showWarning)
					echo -e "${colBad}${line}${colNormal}" >&2
					;;

			showPin) {
				read key val <<< "$line"
				echo -e "${colBindName}${key}<-${colBindValue}${val}${colNormal}" >&2
			};;


			# we want entire UI subshell to have its own tmux pane
			# 
			#
			#
			

			dredge) ;&
		  ask)
				vn=$line

				found=$(
					if [[ -e $contextFile ]]; then
						sed -n '/^'$vn'=.\+$/ { s/^.*=//p }' $contextFile |
							nl | sort -k2 -u | sort -n | cut -f2
					fi
				)

				v=$(
					$fzy --prompt "suggest $vn> " <<< "$found" &
					pid=$!
					echo "pid add dredge:$vn $pid" >&7
					wait "$pid" && echo "pid remove dredge:$vn $pid" >&7
				)

				[[ $? -eq 0 ]] && echo "suggest $vn $v" >&7
				;;

			pick) {
				read -r vn rawVals <<< "$line"

				rawVals=${rawVals#¦}
				rawVals=${rawVals//¦/$'\n'}

				v=$(
					$fzy --prompt "pick ${vn}> " <<< "$rawVals" &
					pid=$!
					echo "pid add pick:$vn $pid" >&7
					wait "$pid" && echo "pid remove pick:$vn $pid" >&7
				)

				[[ $? -eq 0 ]] && echo "suggest $vn $v" >&7
			};;

			fin)
				break
				;;

			esac
		done

		kill "${actorPids[@]}" 2>/dev/null
	} <$uiFifo 7>$cmdFifo
}

lg() {
	[[ $VARS_LOG ]] && echo "$*" >&2
}

main "$@"
