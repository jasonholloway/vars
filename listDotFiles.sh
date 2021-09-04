#!/bin/bash

pattern="$1"
peekDepth="${2:-1}"

find ~+ -maxdepth "$peekDepth" -name "$pattern"

while cd ..; do
	find ~+ -maxdepth 1 -name "$pattern"
	[[ $PWD = / ]] && exit 0
done
