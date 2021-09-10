#!/bin/bash

main() {
	coproc { stdbuf -oL ./bus.awk ; }

	say @ASK deduce
	say "$(<./test.args)"
	say @YIELD

	while read -ru ${COPROC[0]}; do
			case "$REPLY" in
					@PUMP) say;;
					*) echo "$REPLY";;
			esac
	done
}

say() {
		echo "$*" >&${COPROC[1]}
}

main
