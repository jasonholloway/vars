#!/bin/sh

cat <$2 >&1 &
cat <$3 >&2 &
cat -u >$1 <&0

wait
