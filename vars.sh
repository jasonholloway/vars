#!/bin/bash

: ${VARS_PATH:?VARS_PATH must be set!}

source ${VARS_PATH}/common.sh

export VARS_IFACE=${VARS_IFACE:-tmux}
# { tty >/dev/null; } || export VARS_IFACE=simple

export VARS_OUT_FILE="/tmp/vars.out" # could maybe include uuid?
[[ -f $VARS_OUT_FILE ]] && rm -f $VARS_OUT_FILE
touch $VARS_OUT_FILE

export VARS_TMUX_SOCKET=vars2

main() {
	coproc { $VARS_PATH/dispatch.sh "$@"; }
	exec 5<&${COPROC[0]} 6>&${COPROC[1]}

	sesh=

	while hear cmd rest
	do
		case "$cmd" in
			run)
				if [[ ! $sesh ]]; then
					:
				else
					:
				fi


				# am I the first???
				# then we should do new-session; otherwise, splitw
				# but any message system like this needs me here to reply with fifos for listening
				# which is naff, somewhat
				#
				# not least because, how do I reply to multiple possible clients from this one place?
				# via the bus it is possible because communications are serialized
				# each executable fragment should be given its own receiver then
				# to new it up a new pane when requested
				#
				# stderr should be captured into a fifo then
				# and only splurged into a pane if we get that far...
				#
				# but every fragment as its dispatched should go via a handler provided here
				#
				#


							
				run $rest >/dev/null

				;;
			esac
	done

	exec ${VARS_PATH}/render.sh <${VARS_OUT_FILE}
}




handle() {
		# create a fifo for stdin
		# create a fifo for stdout
		# create a fifo for stdout-frisked
		# when we run the fragment, it itself decides whether to use these channels
		# the stdout fifo is itself frisked for special pane commands
		# before being relayed back via other fifo to caller

		# in/out should be provided back to the caller somehow
		# if we were going via the bus we ould support this ******

		# stderr is buffered by default
		# and when we create the first pane we dump its contents there
		
		# do I need a pane?
		# 
		#

		run "$@" 

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

# should do parsing before booting into interface 
# some actions definitely do not want tmux
# parsing should happen here! up top, before the rest
# only alternative is to do seamless upgrade
# ie dispatcher at certain point asks for pane
# which means it will bark an order
# to its parent 'execute this in pane' it says
# so seamless upgrade is possible - but only 
# at cost of extra process... which would be needed anyway!!!!
#
# so at the top here, should run dispatch.sh
# but in event loop
#
# or dispatch could be itself in charge of creating panes
#
#

