#!/bin/bash

[[ $__LIB_OUTLINE ]] || source lib/outline.sh 

expandPins() {
		cat
}

count() {
		while read -r line
		do
				echo "${#line}"
		done
}

rewrite() {
	cat
}

export __LIB_REWRITE=1
