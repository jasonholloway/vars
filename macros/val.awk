BEGIN {
    i=1
    delete vals
}

NR == 1 && sub(":$","",$1) > 0 {
    name=$1

    sub("^\\w+\\W+","")

    split($0,r,"\\|")
    for(i in r) {
        vals[length(vals)]=r[i]
    }
    
    exit
}

NR == 1 {
    name=$1
}

NR > 1 && $1 ~ /[;:]/ {
    sub("^[;:][ \t]*","")
    vals[i]=$0
    i++
}

END {
    print "#++++++++++++++++++++++++++";
    print "# out: "name;
    print "@bind '"name"' '"join(vals, "¦")"'";
    print "";
}


function join(array, sep,    notFirst, key, acc) {
    for(key in array) {
        acc=(acc)(notFirst ? sep : "")(array[key])
        notFirst=1
    }

    return acc
}
