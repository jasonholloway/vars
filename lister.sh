#!/bin/bash

source "${VARS_PATH:-.}/common.sh"

main() {
		local type line
		
		setupBus

		while hear type line; do
				case "$type" in
						"listFiles")
								listFiles
								;;
						
						"listBlocks")
								listBlocks
								;;
				esac

				say "@END"
		done
}

listFiles() {
	local pattern='@*'
	local peekDepth=2

	while read -r fid; do
			echo -n "${fid%%.*} "
	done < <(
			find ~+ -maxdepth "$peekDepth" -name "$pattern" -printf "%p,%T@\n"

			while cd ..; do
				find ~+ -maxdepth 1 -name "$pattern" -printf "%p,%T@\n"
				[[ $PWD = / ]] && exit 0
			done
	)

	echo
}

listBlocks() {
		while read -r file; do
				say "@ASK files"
				say "file $file" #would be even better to do this by batch...
				say "@YIELD"

				hear 
				hear 
				hear 
				hear 
				
		done < <(listFiles)
}

main "$@"
