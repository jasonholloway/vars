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

      echo "" > /tmp/resp

      while true; do
        [[ $move ]] && { read -r line || break; }
        move=

        line=${line//$'\r'/}

        case $mode in
            start)
              if [[ $line =~ ^HTTP.*[Ee]stablished$ ]]; then
                  mode=proxyHeader
                  move=1
              elif [[ $line =~ ^HTTP ]]; then
                  mode=header
                  move=1
              else
                  mode=error
              fi
            ;;

            http)
              read -r schema status rest <<<"$line"

              if [[ ($status -lt 200 || $status -gt 300) && $status -ne 531 ]]; then
                  isError=1
              fi

              [[ $isError ]] && echo "$line" >&2

              if [[ $rest =~ "Connection [eE]stablished" ]]; then
                mode=proxyHeader
              else
                mode=header
              fi

              move=1
            ;;

            header)
              [[ -z $line ]] && mode=body
              [[ $isError ]] && echo "$line" >&2
              move=1
            ;;

            proxyHeader)
              [[ -z $line ]] && mode=http
              [[ $isError ]] && echo "$line" >&2
              move=1
            ;;

            body)
              echo "$line" | tee -a /tmp/resp
              [[ $isError ]] && echo "$line" >&2
              move=1
            ;;

            error)
              isError=1
              move=1
            ;;
        esac
      done

      if [[ $isError ]]; then
        return 1
      fi

    } <<<"$resp"
}

@cacheTill() {
    echo @cacheTill "$@"
}

@cacheFor() {
    echo @cacheFor "$@"
}

@bind() {
    if [[ $# == 1 ]]; then
        while read line; do
            echo @bind "$1" "$line"
        done
    else
        echo @bind "$@"
    fi
}

@bindMany() {
    local vn="$1"
    local -n __r="${2:-results}"
    local IFS='¦'
    echo @bind "$vn" "¦${__r[*]}"
}

@bindHeredoc() {
    local vn="$1"
    local val=$(cat)
    echo @bind "$vn" "${val//$'\n'/$'\036'}"
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
    local line

    IFS=':' read -r sqlServer sqlDb sqlUser sqlPass <<<"$_sql"

    export sqlServer
    export sqlDb
    export sqlUser
    export sqlPass
    export query

    docker run -it \
        --network=host \
        -e sqlServer \
        -e sqlDb \
        -e sqlUser \
        -e sqlPass \
        -e authMode=$([[ $sqlUser =~ '@' ]] && echo "-G " || echo "") \
        -e query \
        sqlcmd \
        /bin/sh -c '
            sqlcmd \
                -S "$sqlServer" \
                $authMode \
                -U "$sqlUser" -P "$sqlPass" \
                -C -K ReadOnly \
                -d "$sqlDb" \
                -h -1 \
                -Q "
                    SET NOCOUNT ON;
                    ${query}"
        ' |
    sed $'s/\r$//' |
    while read -r line; do
        case "$line" in
            "Sqlcmd:"*) {
                echo "$line"
                cat
            } >&2;;

            *) echo "$line";;
        esac
    done
}

@rmf() {
    for p in "$@"; do
        if [[ $p =~ ^/|/\w+|/usr/\w+|/usr/local/\w+|/var/.*|/etc/.*|/lib(64)?/.*$ ]]; then
            echo "Refusing to remove path $p" >&2
            exit 1
        fi

        echo __rm -rf "$p"
    done
}

@json() {
    sed '/:\ *,$/d' | jq .
}
