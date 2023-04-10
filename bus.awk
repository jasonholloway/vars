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

    from="root"
    to="root"
}

debug2 { print RED" "PROCINFO["pid"]" "head"["from" -> "to"] "$0" "NC >"/dev/stderr" }

# if not pumping, then we're buffering
$1 != "@PUMP" {
    buff[++buff["write"]]=$0
    done()
}

$1 == "@PUMP" {
    if(from == "root") {
      if(buff["read"] < buff["write"]) {
        $0=buff[++buff["read"]]
      }
      else {
          next
      }
    }
    else {
      if((procs[from] |& getline) <= 0) {
          print ERRNO >"/dev/stderr"
          exit
      }
    }
}

$1 == "@PUMP" { next }

debug1 { print PROCINFO["pid"]" "head"["from" -> "to"] "$0 >"/dev/stderr" }



$1 == "@ERROR" {
    gsub("^@ERROR\\s+", "")

    print "error"
    print $0
}

$1 == "@ASK" {
    pushConv()
    to=$2
    done()
}

$1 == "@YIELD" {
    swapConv()
    done()
}

$1 == "@END" {
    if(head == 0) exit
    else popConv()
    done()
}

{
    if(to == "root") {
        print $0
    }
    else if(procs[to]) {
        print |& procs[to]
    }

    done()
}

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

function done() {
    if(debug2) print RED"["from" -> "to"]"NC" ("PROCINFO["pid"]")" >"/dev/stderr"
    print "@PUMP"
    next
}
