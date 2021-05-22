

@curl() {
    curl -Ss -Lk \
         $([ ! -z $VARS_VERBOSE ] && echo "-v") \
         $([ ! -z $VARS_PROXY ] && echo "--proxy $VARS_PROXY") \
         "$@"
}

@cacheTill() {
    echo @set cacheTill "$@"
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

