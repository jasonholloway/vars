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

	pumpPids=()

	fifoIn="/tmp/vars-in.fifo"
	[[ ! -p "$fifoIn" ]] && mkfifo "$fifoIn"
	cat >$fifoIn <&5 &
	pumpPids+=($!)

	fifoOut="/tmp/vars-out.fifo"
	[[ ! -p "$fifoOut" ]] && mkfifo "$fifoOut"
	cat <$fifoOut >&6 &
	pumpPids+=($!)

	tmux -Lvars new-session ${VARS_PATH}/interact.sh $fifoIn $fifoOut $contextFile $outFile

	kill "${pumpPids[@]}" 2>/dev/null
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
