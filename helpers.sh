#!/bin/bash

@curl() {
    local line

		resp=$(curl -Ss -Lk -i \
					$([[ $VARS_VERBOSE ]] && echo "-v") \
					$([[ $VARS_PROXY ]] && echo "--proxy $VARS_PROXY") \
					"$@" 2>&1)

		{
			local mode=start
			local move=1
			local schema status isError

			while true; do
				[[ $move ]] && { read -r line || break; }
				move=

				line=${line//$'\r'/}

				case $mode in
						start)
							if [[ $line =~ ^HTTP ]]; then
									mode=http
							else
									mode=error
							fi
						;;

						http)
							read -r schema status _ <<<"$line"
							[[ ! ($status -ge 200 && $status -lt 300) ]] && echo "$line" >&2
							mode=header
							move=1
						;;

						header)
							[[ -z $line ]] && mode=body
							[[ ! ($status -ge 200 && $status -lt 300) ]] && echo "$line" >&2
							move=1
						;;

						body)
							echo "$line" 
							[[ ! ($status -ge 200 && $status -lt 300) ]] && echo "$line" >&2
							move=1
						;;

						error)
							echo "$line" >&2
							isError=1
							move=1
						;;
				esac
			done

			[[ $isError ]] && return 1

		} <<<"$resp"
}

@cacheTill() {
    echo @cacheTill "$@"
}

@cacheFor() {
    echo @cacheFor "$@"
}

@bind() {
    echo @bind "$@"
}

# @tty() {
#     eval "$@" >$(tty)
# }

@k() {
    IFS=: read context namespace <<< "$k8s"
    [[ $context && $namespace ]] &&
        kubectl --context $context --namespace $namespace $@
}

@bcp() {
    local connString="$1"
    shift
    
    opts=$(
        echo "$connString" |
            sed 's/;/\n/g' |
            while IFS='=' read key val; do
                case $key in
                    "Data Source")
                        echo "-S$val"
                        ;;
                    "Initial Catalog")
                        echo "-d$val"
                        ;;
                    "uid")
                        echo "-U$val"
                        ;;
                    "pwd")
                        echo "-P$val"
                        ;;
                esac
            done |
            xargs
        )

    bcp $@ $opts >&2
}

