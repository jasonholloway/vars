#!/bin/bash
shopt -s extglob

source "${VARS_PATH:-.}/common.sh"

cacheDir="$HOME/.vars/cache"

main() {
  local type block

  setupBus

  while hear type rest; do
    case "$type" in
				cacheData)
						cacheData $rest
            ;;
    esac

    say "@YIELD"
  done
}

cacheData() {
  echo "CACHE DATA!" >&2

  say woofwoofwoof


		# IFS=$FS read -r bid _ _ _ blockFlags <<< "$*"

		# while hear type line; do
		# 		case $type in
		# 				arg) args+=("$line");;
		# 				flags) runFlags=$line;;
		# 				val) vals+=("$line");;
		# 				go) break;
		# 		esac
		# done
}

