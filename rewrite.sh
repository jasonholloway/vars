#!/bin/bash

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
	echo hello from rewrite
	cat
	echo woooo
}

