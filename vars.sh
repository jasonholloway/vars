#!/bin/bash
shopt -s extglob

: ${VARS_PATH:?VARS_PATH must be set!}

source "${VARS_PATH:-.}/common.sh"

declare -a words=($@)
declare -a blocks=()
declare -a flags=()
declare -a adHocs=()
declare -a cmds=()
declare -a extraOutlines=()
declare w

colBindName='\033[0;36m'
colBindValue='\033[0;35m'
colGood='\033[0;32m'
colBad='\033[0;31m'
colNormal='\033[0m'
colDim='\e[38;5;240m'
colDimmest='\e[38;5;236m'

fzy="$VARS_PATH/fzy/fzy"
cacheDir="$HOME/.vars/cache"
contextFile="$HOME/.vars/context"
outFile="$HOME/.vars/out"

pts=$(tty)

main() {
	mkdir -p $cacheDir

	parseMany parseFlag \
	&& {
			 parseGet \
		|| parseRun \
		|| parsePin \
		|| parseContext \
		|| parsePrep \
		|| parseLs \
		|| parseEdit \
		|| parseLoad \
		|| parseCache
		}

	[[ ${flags[*]} =~ q || ! -t 1 ]] && local quietMode=1
	[[ ${flags[*]} =~ v ]] && local verboseMode=1

	if [[ ${#cmds[@]} -gt 0 ]]; then
		{
			coproc {
				$VARS_PATH/bus.pl "files:$VARS_PATH/files.sh;blocks:$VARS_PATH/blocks.sh;deducer:$VARS_PATH/deducer.pl;hist:$VARS_PATH/history.sh;runner:$VARS_PATH/runner.sh $pts;io:$VARS_PATH/io.pl $pts"
			}
			exec 5<&${COPROC[0]} 6>&${COPROC[1]}

			dispatch ${cmds[@]}

			exec 5<&- 6>&-
		} | render
	fi
}

dispatch() {
		local curr
		local -a ac;

		while :; do
				curr=$1
				shift
				
				case "$curr" in
						"|")
								"${ac[@]}" | dispatch $@
								break
								;;
						"")
								"${ac[@]}"
								break
								;;
						*)
								ac+=("$curr")
								;;
				esac
		done
}

run() {
	local fids outlines type line currentBlock sink
	local timerFifo cmdFifo killFifo receiverPid timerPid killPid
	local -A dredgingPid=()

	say '@ASK io'
	say 'getPipe'
	hear _ sink
	say 'getPty'
	hear _ pty
	say '@END'

	say "@ASK files"
	say "find"
	hear fids
	say "@END"

	say "@ASK files"
	say "outline $fids"
	hear outlines
	say "@END"

	say "@ASK deducer"
	say "deduce"
	say "$outlines${RS}${extraOutlines[*]}"
	say "${blocks[*]}"
	say "${flags[*]}"

	rm -f "$outFile" || :

	cmdFifo="/tmp/vars-cmds"
	[[ ! -p "$cmdFifo" ]] && mkfifo "$cmdFifo"

	uiFifo="/tmp/vars-ui"
	[[ ! -p "$uiFifo" ]] && mkfifo "$uiFifo"

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
	done <&5 7>$cmdFifo 8>$uiFifo
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
				echo "$line" >> "$outFile"
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
	done <$cmdFifo 7>$cmdFifo 8>$uiFifo 
}

uiActor() {
	{
		fzy="$fzy -t $pty"

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
							src=${shortPath}$([[ $index ]] && echo "|$index")

							case "$src" in
									cache*) key="\`$key";;
									pin*) key="!$key";;
							esac

							[[ ${#val} -gt 80 ]] && { val="${val::80}..."; }
							echo -e "${colBindName}${key}=${colBindValue}${val} ${colDimmest}${src}${colNormal}" >&2
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
	} <$uiFifo 7>$cmdFifo 1>$sink 2>$sink
}



list() {
	local fids names outs ins
	local -a outlines

	findOutlines outlines

	for outline in ${outlines[@]}; do
			
			local IFS=$FS; read -r bid names ins outs flags <<<"$outline"

			local IFS=$','
			for name in $names; do
					echo "B;$name;$bid"
			done

			for inp in $ins; do
					echo "I;${inp%\*};$bid"
			done

			for out in $outs; do
					echo "O;${out%\*};$bid"
			done
	done
}

findOutlines() {
	local -n __into=$1
	local fids _outlines

	say "@ASK files"
	say "find"
	hear fids
	say "@END"

	say "@ASK files"
	say "outline $fids"
	hear _outlines
	say "@END"

	IFS=$RS
	__into+=($_outlines)
}

edit() {
		local bid file ln
		
		while [[ "$1" ]]; do
				bid=$1;

				[[ $bid =~ ^([^,]+),([0-9]+)\|([0-9]+) ]] || exit 1
				file=${BASH_REMATCH[1]}
				ln=${BASH_REMATCH[3]}

				case "$EDITOR" in
						emacsclient*)
								eval "$EDITOR +$ln $file" >$pts;;
						vi*)
								eval "$EDITOR +'100|norm! zt' $file" >$pts;;
						*)
								eval "$EDITOR $file" >$pts;;
				esac

				shift
		done
}

editPick() {
		local -a outlines

		findOutlines outlines

		edit $(for o in ${outlines[@]}; do echo "${o//$FS/;}"; done | $fzy --prompt "${name}> ")
}

filterList() {
		local type=$1
		while read -r line; do
				[[ ${line:0:2} == "$type;" ]] && echo "${line:2}"
		done
}

relativizeList() {
		local -A relDirs=()
		
		while read -r line; do
				IFS=\; read -r name bid _ <<<"$line"
				IFS=\| read -r fid _ <<<"$bid"
				IFS=\, read -r file _ <<<"$fid"

				relDir=${relDirs[$file]}

				if [[ ! $relDir ]]; then
					dir=$(dirname "$file")
					relDir=$(realpath --relative-to="$PWD" "$dir")
					relDirs[$file]=$relDir
				fi

				echo "$relDir/$name;$relDir;$line"
		done
}

shift1() {
	i=$((i + 1))
}

parse1() {
	local re=$1
	local _w=${words[$i]}
	[[ $_w =~ $re ]] \
			&& w=$_w \
			&& shift1
}

parseMany() {
	while eval "$@"; do :; done
}

parseGet() {
	parse1 '^(g|ge|get)$' \
		&& parseNames targets \
		&& {
			for t in $targets; do
				blocks+=("get:$t")
				extraOutlines+=("get:$t")
			done
			cmds+=("run")
		}
}

parseRun() {
	parse1 '^(r|ru|run)$' \
		&& parseNames blocks \
		&& {
			cmds+=("run")
		}
}

parsePrep() {
	parse1 '^(p|prep)$' \
		&& flags+=(p) \
		&& parseNames blocks \
		&& {
			cmds+=("run")
		}
}

parseLs() {
	parse1 '^(ls|list)$' \
		&& {
			cmds+=("list")

			{
				parse1 '^(b|bl|block|blocks)' \
					&& cmds+=("| filterList B")
			} || {
				parse1 '^(o|out|outs)' \
					&& cmds+=("| filterList O")
			}
			# } || {
			#		parse1 '^(i|in|ins)' \
			#			&& cmds+=("| filterList I")
			# }

			parse1 '^rel' \
				&& cmds+=("| relativizeList")
	}
}

parseEdit() {
	parse1 '^(e|ed|edit)$' \
		&& {
			{
				parse1 'pick' \
					&& cmds+=('editPick')
			} || {
				parse1 'bid' \
						&& parseMany "parseName bids" \
						&& cmds+=("edit" "${bids[@]}")
			}
	}
}

parsePin() {
	parse1 '^(p|pi|pin)$' \
		&& {
			{
				parse1 '^(l|li|lis|list|ls)$' \
				&& $VARS_PATH/context.sh listPinned
			} || {
				parse1 '^(c|cl|clear)$' \
				&& $VARS_PATH/context.sh clearPinned
			} || {
				parse1 '^(u|unpin|r|rm|remove)$' \
					&& {
						parseMany "parseName targets" \
						&& $VARS_PATH/context.sh unpin "${targets[@]}"
					}
			} || {
				parseMany "parseName targets" \
					&& {
						$VARS_PATH/context.sh pin "${targets[@]}"
					}
			}
		}
}

parseContext() {
	parse1 '^(x|con|cont|conte|contex|context)$' \
			&& {
					{
						parse1 '^(l|li|lis|list|ls)$' \
						&& $VARS_PATH/context.sh list
					} || {
						parse1 '^(c|cl|clear)$' \
						&& $VARS_PATH/context.sh clearContext
					} || {
						parse1 '^prev(ious)?$' \
						&& $VARS_PATH/context.sh previous
					} || {
						$VARS_PATH/context.sh list
					}
				}
}

parseLoad() {
	local count block
	parse1 '^load$' \
		&& {
			parse1 '^[0-9]+$' && count=$w
		} \
		&& {
			parse1 '.+' && block=$w
		} \
		&& "$VARS_PATH/varsLoad.sh" "$count" "$block"
}

parseCache() {
	parse1 '^cache$' \
		&& (
			(parse1 '^clear$' \
				&& rm -rf $cacheDir/* \
				&& echo cleared cache!) \
			|| find $cacheDir -type d
		)
}

parseFlag() {
	parse1 '^-[a-zA-Z]+$' \
		&& {
			local i
			for (( i=1 ; i < ${#w} ; i++ )); do
				flags+=(${w:i:1});
			done
		}
}

parseAdHocBind() {
	parse1 '^\w+=.+$' \
		&& adHocs+=($w)
}

parseName() {
	local -n into=$1
	parse1 '.+' \
		&& into+=($w)
}

parseNames() {
	parseMany "parseFlag || parseAdHocBind || parseName $1"
}

parseArg() {
	local w=${words[$i]}
	[[ ! -z $w ]] \
			&& shift1 \
			&& echo "$w"
}

render() {
	source "$VARS_PATH/render.sh"
}

lg() {
	[[ $VARS_LOG ]] && echo "$*" >&2
}

main "$@"
