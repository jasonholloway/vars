#!/usr/bin/awk -f

BEGIN {
    RED="\33[0;31m"
    NC="\33[0m"

    debug1=ENVIRON["VARS_DEBUG"]
    debug2=0

    head=0

    buff["read"]=10000
    buff["write"]=10000

    split(PROCS,specs,";")
    for(i in specs) {
        split(specs[i],p,":")
        procs[p[1]]=p[2]
    }
}

debug2 { print RED" "PROCINFO["pid"]" "head"["from" -> "to"] "$0" "NC >"/dev/stderr" }

{ swap=0; pop=0; printIt=1; talkTo="" }


# Buffer incoming lines
! /^@PUMP/ {
    buff[++buff["write"]]=$0
    forward()
}

# Pump to lower rules
from {
    if((procs[from] |& getline) <= 0) {
        print ERRNO >"/dev/stderr"
        exit
    }
}

!from {
    if(buff["read"] >= buff["write"]) next
    else {
        $0=buff[++buff["read"]]
    }
}

# Non-roots can't pump (?)
/^@PUMP/ { next }

debug1 { print PROCINFO["pid"]" "head"["from" -> "to"] "$0 >"/dev/stderr" }


/^@ERROR/ {
    gsub("^@ERROR\\s+", "")

    print "error"
    print $0
}

/^@ASK/ {
    talkTo=$2
    printIt=0
}

/^@YIELD/ || /^@Y$/ {
    swap=1
    printIt=0
}

/^@END$/ || /^@E$/ {
    pop=1
    printIt=0
}

printIt && to && procs[to] { print |& procs[to] }

printIt && !to { print $0 }

talkTo {
    pushConv()
    to=$2
}

swap {
    swapConv()
}

pop {
    if(head == 0) exit
    else popConv()
}

{ forward() }


function pushConv() {
    convs[head]["from"]=from
    convs[head]["to"]=to
    head++
}

function popConv() {
    head--
    from=convs[head]["from"]
    to=convs[head]["to"]
    delete convs[head]
}

function swapConv(_tmp) {
    _tmp=from
    from=to
    to=_tmp
}

function forward() {
    if(debug2) print RED"["from" -> "to"]"NC" ("PROCINFO["pid"]")" >"/dev/stderr"
    print "@PUMP"
    next
}
