BEGIN {
    i=1
    delete vals
}

NR == 1 {
    name=$1
}

NR > 1 && $1 == ";" {
    vals[i]=$2
    i++
}

END {
    print "#++++++++++++++++++++++++++";
    print "# out: "name;
    print "@bind "name" ¦"join(vals, "¦");
    print "";
}


function join(array, sep,    notFirst, key, acc) {
    for(key in array) {
        acc=(acc)(notFirst ? sep : "")(array[key])
        notFirst=1
    }

    return acc
}