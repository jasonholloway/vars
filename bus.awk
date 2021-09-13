#!/usr/bin/awk -f

BEGIN {
  RED="\33[0;31m"
  NC="\33[0m"

  debug=1
  head=0

  split(PROCS,specs,";")
  for(i in specs) {
      split(specs[i],p,":")
      procs[p[1]]=p[2]
  }
}

from {
    if((procs[from] |& getline) <= 0) {
        print ERRNO >"/dev/stderr"
        exit
    }
}

debug {
    print "["from" -> "to"] "$0" ("PROCINFO["pid"]")" >"/dev/stderr"
}


/^@PUMP/ || /^@$/ { forward() }

/^@ASK/ {
    pushConv()
    to=$2
    forward()
}

/^@YIELD/ || /^@Y$/ {
    swapConv()
    forward()
}

/^@END$/ || /^@E$/ {
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

!to { print $0; forward() }

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
    if(debug) print RED"["from" -> "to"]"NC" ("PROCINFO["pid"]")" >"/dev/stderr"
    if(from) print "@PUMP"
    next
}
