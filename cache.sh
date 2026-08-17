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
				openSinks) openSinks $rest;;
				closeSinks) closeSinks $rest;;
				dump) dump $rest;;
    esac

    say "@YIELD"
  done
}

dump() {
	local token=$1
	say "${stash[$token]}"
}

peek() {
	local key line hash cacheFile foundKey

	# set -x

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
							SINK)
									read _ fn sinkFile _ <<<"$rest"

									if [[ -e "$sinkFile" ]]; then
										mv "$sinkFile" "${fn@P}"
										echo "FILE $fn"
									fi
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

openSinks() {
	local token name fn ext sinkFile hash created

	token="$1"

	stash[$token]+=$(
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
		} <<<"${stash[$token]}"

		echo

		while hear name && [[ ! -z "$name" ]]; do
			#todo filenum too!
			fn="\${dataDir}/${name%.*}.${hash}.${created:-0}"
			ext="${name##*.}"
			if [[ ! -z "$ext" && "$ext" != "$name" ]]; then fn+=".${ext}"; fi

			sinkFile=$(mktemp -u)
			echo "SINK $name $fn $sinkFile"

			say "$sinkFile"
		done
	)
}

closeSinks() {
	local token line type rest fn sinkFile

	token="$1"

	{
		while read line; do
			case "$line" in
					"SINK "*)
							read _ name fn sinkFile <<< "$line"

							if [[ -e "$sinkFile" ]]; then
								lastMod=$(stat --format=%Y "$sinkFile")
								say "$name file;$fn;$lastMod"
							else
								echo "nothing written to data sink $sinkFile!" >&2
							fi
							;;
			esac
		done

		say
	} <<< "${stash[$token]}"



	# {
	# 	stash[$token]=$(
	# 		while read line; do
	# 			case "$line" in
	# 					"SINK "*)
	# 							read _ name fn sinkFile <<< "$line"

	# 							if [[ -e "$sinkFile" ]]; then
	# 								stash[$token]+=$'\n'"STAGEDFILE $fn $sinkFile"
	# 								lastMod=$(stat --format=%Y "$sinkFile")
	# 								say "$name file;$fn;$lastMod"
	# 							else
	# 								echo "nothing written to data sink $sinkFile!" >&2
	# 							fi
	# 							;;
	# 					*)
	# 							echo "$line"
	# 							;;
				
	# 			esac
	# 		done
	# 	)

	# 	say
	# } <<< "${stash[$token]}"
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
