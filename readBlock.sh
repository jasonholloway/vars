#!/bin/bash

source ${VARS_PATH:-.}/common.sh

main() {
		local type line
		
		setupBus

		while hear type line; do
				case "$type" in
						"read")


								;;
		done
}

main "$@"





# deducer wants outlines in order to order them
# then it wants to run them
#
# the files service says what blocks there are
# but to do this it needs to read the actual blocks
#
# the blocks service would run a block
# but this also needs the blocks 
#
#
#    LISTER -> FILES -> BLOCKS
#    we want outlines served to the deducer up front as block specs
#    DEDUCER -> RUNNER -> BLOCKS
#
# currently it is quite separate; DEDUCER takes in names of files
# but it shouldn't be like this!
# we want to pipe in block outlines up front
#
# we need a LISTER module then - given file location, get list of outlines back
# this list of outlines can then be used to choose targets
