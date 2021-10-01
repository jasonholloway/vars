#!/bin/bash

@curl() {
		local args=("$@")
    local line

		{ while read -r line; do
				line=${line//$'\r'/}
				[[ -z $line ]] && { echo "" >&2; } && break
				echo "HEADER $line" >&2
			done

			while read -r line; do
				echo "BODY $line" >&2
				echo "$line"
			done
		} <<<$(
			curl -Ss -Lk -i \
					$([[ $VARS_VERBOSE ]] && echo "-v") \
					$([[ $VARS_PROXY ]] && echo "--proxy $VARS_PROXY") \
					"${args[@]}"
			)
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

@tty() {
    echo @tty $@
}

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

