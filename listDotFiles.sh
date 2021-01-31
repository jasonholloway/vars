#!/bin/bash
shopt -s extglob

for relGlob in "$@"; do
	pp=""
	echo "$PWD" \
	| tr '/' '\n' \
	| while read -r p; do \
			pp="$pp$p/"; \
			ls -d "$pp"$relGlob 2>/dev/null; \
		done
done

