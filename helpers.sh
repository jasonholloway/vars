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
						  case $line in
								HTTP*) mode=http ;;
								*) mode=error ;;
						  esac
						;;

						http)
							read -r schema status rest <<<"$line"
							[[ ! ($status -ge 200 && $status -lt 300) ]] && echo "$line" >&2

							if [[ $rest =~ "Connection Established" ]]; then
								mode=proxyHeader
						  else
								mode=header
							fi

							move=1
						;;

						header)
							[[ -z $line ]] && mode=body
							[[ ! ($status -ge 200 && $status -lt 300) ]] && echo "$line" >&2
							move=1
						;;

						proxyHeader)
							[[ -z $line ]] && mode=start
							[[ ! ($status -ge 200 && $status -lt 300) ]] && echo "$line" >&2
							move=1
						;;

						body)
							echo "$line" 
							[[ ! ($status -ge 200 && $status -lt 300) ]] && echo "$line" >&2
							move=1
						;;

						error)
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

@bindMany() {
		local vn="$1"
		local -n __r="${2:-results}"
		local IFS='¦'
		echo @bind "$vn" "¦${__r[*]}"
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

@sql() {
		local query="$1"
		local -n sink="${2:-results}"
		local line

		IFS=':' read -r sqlServer sqlDb sqlUser sqlPass <<<"$_sql"

		sink=()

		while read -r line
		do sink+=("$line")
		done < <(
				SQLCMDPASSWORD="$sqlPass" \
						sqlcmd \
								-S $sqlServer \
								-C -G -U "$sqlUser" \
								-K ReadOnly \
								-d $sqlDb \
								-h -1 \
								-Q "
				SET NOCOUNT ON;
				${query}
				")
}

