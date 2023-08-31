#!/bin/bash

: ${VARS_PATH:?VARS_PATH must be set!}

export VARS_IFACE=${VARS_IFACE:-tmux}
# { tty >/dev/null; } || export VARS_IFACE=simple

export VARS_OUT_FILE="/tmp/vars.out" # could maybe include uuid?
[[ -f $VARS_OUT_FILE ]] && rm -f $VARS_OUT_FILE
touch $VARS_OUT_FILE

export VARS_TMUX_SOCKET=vars2

main() {
	run ${VARS_PATH}/dispatch.sh "$@"
	exec ${VARS_PATH}/render.sh <${VARS_OUT_FILE}
}

run() {
	case "$VARS_IFACE" in
		tmux)
			tmux -L${VARS_TMUX_SOCKET} -f${VARS_PATH}/tmux/config new-session "$@" >/dev/null
		;;
		simple)
			"$@" >/dev/null
		;;
		*)
			echo "unknown VARS_IFACE $VARS_IFACE" >&2
			exit 1
		;;
	esac
}

main "$@"

