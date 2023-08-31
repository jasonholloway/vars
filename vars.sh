#!/bin/bash

: ${VARS_PATH:?VARS_PATH must be set!}

export VARS_OUT_FILE="/tmp/vars.out" # could maybe include uuid?
[[ -f $VARS_OUT_FILE ]] && rm -f $VARS_OUT_FILE
touch $VARS_OUT_FILE

export VARS_TMUX_SOCKET=vars2
# export VARS_LOG_SINK=/tmp/vars.log

tmux -L${VARS_TMUX_SOCKET} -f${VARS_PATH}/tmux/config new-session ${VARS_PATH}/dispatch.sh "$@" >/dev/null

exec ${VARS_PATH}/render.sh <${VARS_OUT_FILE}

#
# dispatch needs to be offering panes out as requested
#
#
# we want 1 log: which includes binds
# so when we log, we don't log to stderr (though: all these logs are coming from the bus)
# STDERR could then be the means of joining all these streams happily together
# wherever a line comes from
# this would also mean we only ever write the result to STDOUT
#
