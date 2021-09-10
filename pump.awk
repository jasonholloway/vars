#!/usr/bin/awk -f

BEGIN {
  modesHead=0
  copsHead=0
    
  deducer="stdbuf -oL ./deduceVarBinds.sh"
  files="./files.sh"

  while((getline l <"test.args") > 0) {
      print l |& deducer
  }

  pushCop(deducer)
  pushMode("read")
}

{print "<"m","cop">"}

m=="end" {
    exit
}

m=="read" {
    if((cop |& getline) <= 0) m="end"
}



cop==deducer && /^run/ {
    pushMode("run")
    print
    next
}

m=="run" && /~/ { # /\043/ {
    popMode()
    print |& deducer
    next
}

m=="run" {
    print |& deducer
    next
}



/^list/ {
    print "LIST "$0
    next
}




/^CONNECT/ {
    peer=$2

    #and here we push a new conversation onto the stack
    #and our program continues to ping-pong
    #between peers

    #who's talking? a coproc; all are coprocs
}

"DISCONNECT" {

}



src && dst {
    while((src |& getline) > 0 && $0 != ".") {
        print $0 |& dst
    }
}


cop==deducer && /^targets/ {
    print $0
    next
}


cop==deducer && /^pick/ {
    print $0
    next
}


/^bind/ {
    print $0 |& deducer
    readFrom=deducer
    next
}

/^bound/ {
    print $0
    next
}


/^out/ {
    print $0
    next
}




function pushMode(n) {
    modes[modesHead]=n
    modesHead++
    m=n

    # for (i in modes) print "modes["i"]="modes[i]
}

function popMode() {
    modesHead--
    delete modes[modesHead]
    m=modes[modesHead-1]
    # for (i in modes) print "modes["i"]="modes[i]
}



function pushCop(n) {
    cops[copsHead]=n
    copsHead++
    cop=n
    # print "cop="cop
}

function popCop() {
    copsHead--
    delete cops[copsHead]
    cop=cops[copsHead-1]
    # print "cop="cop
}

