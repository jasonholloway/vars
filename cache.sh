#!/bin/bash
shopt -s extglob

source "${VARS_PATH:-.}/common.sh"

cacheDir="$HOME/.vars/cache"
dataDir="$cacheDir/data"
mkdir -p $dataDir

main() {
  local type block

  setupBus

  while hear type rest; do
    case "$type" in
				peekBlock)
						peekBlock $rest
						;;

				putData)
						putData $rest
            ;;
    esac

    say "@YIELD"
  done
}

peekBlock() {
	local header line hash cacheFile foundHeader
	local -A stash=()

	# header should be the block id, followed by input bindings
	# but this is all opaque to us
	header=$(
		while hear line && [[ ! -z $line ]]; do
			echo "$line"
		done
	)

	hash=$(sha1sum <<< "$header")
	cacheFile="$dataDir/${hash%% *}"

	if [[ -e "$cacheFile" ]]; then
		{
			foundHeader=$(
				while read line && [[ ! -z $line ]]; do
					echo "$line"
				done
			)

			if [[ "$foundHeader" == "$header" ]]; then
				say "hit"

				while read line && [[ -z $line ]]; do
					say "$line"
				done

				say
				say "@YIELD"
			fi
		} <"$cacheFile"

		return
	fi

	say "miss"
	# todo.....  pass some token back to runner so that we don't have to
	# got through the header/hash rigmarole again
}

# todo below should take name hint
# and not have anything to do with hashing etc
# (could take a cache token?)

putData() {
	local line header hash cacheFile dataFile dataFileNum specs
	local -a dataFiles=()
	local -a specs=()

	header=$(
		while hear line && [[ ! -z $line ]]; do
			echo "$line"
		done
	)

	hash=$(sha1sum <<< "$header")
	cacheFile="$dataDir/${hash%% *}"
	dataFileNum=0

	{
		echo "$header" 

		echo

		while hear line && [[ $line != "fin" ]]; do
			dataFile="${cacheFile}.${dataFileNum}.data"

			say "$dataFile"
			say "@YIELD"

			hear

			if [[ -e "$dataFile" ]]; then
				echo "$dataFile"
				lastMod=$(stat --format=%Y "$dataFile")
				specs+=("file;$dataFile;$lastMod")
			fi

			fileNum=$((dataFileNum+1))
		done
	} >"$cacheFile"

	echo HELLO >&2

  IFS=| say "${specs[*]}"
}

main "$@"
