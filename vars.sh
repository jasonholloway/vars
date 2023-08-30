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
