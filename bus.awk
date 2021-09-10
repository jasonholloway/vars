#!/usr/bin/awk -f

BEGIN {
  debug=0
  head=0
  from=""
  to=""
}

/^@PROC / {
    n=$2
    $1=""; $2=""
    procs[n]=$0
    next
}

from {
    if((procs[from] |& getline) <= 0) {
        print ERRNO >"/dev/stderr"
        exit
    }
}

/^@PUMP/ { next }

/^@ASK/ {
    pushConv()
    to=$2
    forward()
}

/^@YIELD/ {
    swapConv()
    forward()
}

/^@END/ {
    if(head == 0) exit
    else {
      popConv()
      forward()
    }
}

to {
    print |& procs[to]
    forward()
}

!to { print; forward() }


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
    if(debug) { print "["from", "to"]" >"/dev/stderr" }
    print "@PUMP"
    next
}

