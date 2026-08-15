#!/bin/bash
shopt -s extglob

source "${VARS_PATH:-.}/common.sh"

cacheDir="$HOME/.vars/cache"
blockDir="$cacheDir/blocks"
dataDir="$cacheDir/data"
mkdir -p $blockDir $dataDir

declare nextStashKey=0
declare -A stash=()

main() {
  local type block

  setupBus

  while hear type rest; do
    case "$type" in
				peek) peek $rest;;
				put) put $rest;;
				release) release $rest;;
				stageFile) stageFile $rest;;
    esac

    say "@YIELD"
  done
}

peek() {
	local key line hash cacheFile foundKey

	set -x

	# header should be the block id, followed by input bindings
	# but this is all opaque to us
	key=$(
		while hear line && [[ ! -z "$line" ]]; do
			echo "$line"
		done
				)

	hash="$(sha1sum <<< "$key")"
	hash="${hash%% *}"
	cacheFile="$blockDir/${hash}"
	missed=

	if [[ -e "$cacheFile" ]]; then
		{
			while read type rest; do
				case $type in
						KEY)
								foundKey=$(
									while read line && [[ "$line" != ';' ]]; do
										echo "$line"
									done
								)

								if [[ "$foundKey" != "$key" ]]; then
									missed=1
									break
								fi
								;;

						FILE)
								fn="${rest@P}"

								if [[ ! -e "$fn" ]]; then
									missed=1
									break
								fi
								;;

						OUT)
								break
								;;
				esac
			done

			if [[ ! $missed ]]; then
				say "hit"

				while read line; do
					say "$line"
				done

				say
				return
			fi
		} <"$cacheFile"
	fi

	token="_${nextStashKey}"
	nextStashKey=$((nextStashKey+1))
	stash["$token"]="$(cat <<EOF
$cacheFile
KEY
$key
;
HASH ${hash}
CREATED ${EPOCHSECONDS}
EOF
)"

	say "miss"
	say "$token"
}

put() {
	local hash cacheFile
	local token="$1"
	local stashed="${stash[$token]}"

	if [[ ! -z "$stashed" ]]; then
		{
			read cacheFile

			{
				while read type rest; do
					case "$type" in
							KEY)
									echo "KEY"
									while read line; do
										echo "$line"
										[[ $line == ';' ]] && break
									done
							;;
							STAGEDFILE)
									read fn tmpFile <<<"$rest"
									mv "$tmpFile" "${fn@P}"
									echo "FILE $fn"
							;;
					esac
				done

				while hear line && [[ ! -z "$line" ]]; do
					echo "$line"
				done
			} >"$cacheFile"
		} <<<"$stashed"
	fi
}

release() {
	local token="$1"
	unset stash["$token"]

	#todo delete tmp file
}

stageFile() {
	local token name stashed fn ext dataFile tmpFile hash created
	token="$1"
	name="$2"
	stashed="${stash[$token]}"

	if [[ ! -z $stashed ]]; then
		{
			read _

			while read type rest; do
				case "$type" in
						HASH)
								hash="$rest"
								;;
						CREATED)
								created="$rest"
								break #always after HASH
								;;
				esac
			done
		} <<<"$stashed"

		fn="\${dataDir}/${name%.*}.${hash}.${created:-0}"
		ext="${name##*.}"

		if [[ ! -z "$ext" ]]; then
			fn+=".${ext}"
		fi

		tmpFile=$(mktemp -u)

		say "$tmpFile"
		say "@YIELD"

		hear

		if [[ -e "$tmpFile" ]]; then
			stash[$token]+=$'\n'"STAGEDFILE $fn $tmpFile"
			lastMod=$(stat --format=%Y "$tmpFile")
			say "file;$fn;$lastMod"
		else
			echo "cache data file not written!" >&2
			say
		fi
	fi
}





# # todo below should take name hint
# # and not have anything to do with hashing etc
# # (could take a cache token?)

# putData() {
# 	local line header hash cacheFile dataFile dataFileNum specs
# 	local -a dataFiles=()
# 	local -a specs=()

# 	header=$(
# 		while hear line && [[ ! -z $line ]]; do
# 			echo "$line"
# 		done
# 	)

# 	hash=$(sha1sum <<< "$header")
# 	cacheFile="$dataDir/${hash%% *}"
# 	dataFileNum=0

# 	{
# 		echo "$header" 

# 		echo

# 		while hear line && [[ $line != "fin" ]]; do
# 			dataFile="${cacheFile}.${dataFileNum}.data"

# 			say "$dataFile"
# 			say "@YIELD"

# 			hear

# 			if [[ -e "$dataFile" ]]; then
# 				echo "$dataFile"
# 				lastMod=$(stat --format=%Y "$dataFile")
# 				specs+=("file;$dataFile;$lastMod")
# 			fi

# 			fileNum=$((dataFileNum+1))
# 		done
# 	} >"$cacheFile"

# 	echo HELLO >&2

#   IFS=| say "${specs[*]}"
# }

main "$@"
