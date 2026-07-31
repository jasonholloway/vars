BEGIN {
    ruleI=0
    valI=0
    heredoc=0

    heredocIns=""
    heredocText=""
}

# { print $0 > "/dev/stderr" }

# start heredoc
/^ *[;:].*<<EOF$/ {
    gsub("^\\s*[;:]\\s*", "")
    gsub("<<EOF$", "")
    heredoc=1
    heredocIns=$0
    heredocText=""
    next
}

# end heredoc
heredoc && /^EOF/ {
    vals[valI]=heredocText
    rules[ruleI++]=heredocIns valI
    valI++
    
    heredoc=0
    next
}

# continue heredoc
heredoc {
    if(heredocText) {
        heredocText = heredocText"\n"$0
    }
    else {
        heredocText = $0
    }
    next
}

# empty
/^ *$/ || /^#/ { next }

# header
! /^ *[;:]/ {
    split($0, parts, / *> */)
    split(parts[1], ins, / *, */)
    split(parts[2], outs, / *, */)
    
    print "#++++++++++++++++++++++++++"
    print "# in: "join(ins, " ")
    print "# out: "join(outs, " ")
    next
}

# rule
/^ *[;:]/ {
    gsub("^\\s*[;:]\\s*", "")

    split($0, parts, / *> */)
    split(parts[1], rIns, / *, */)
    split(parts[2], rOuts, / *, */)

    for(i in rIns) {
        v=rIns[i]

        if(v !~ /[|*]/) {
            v="\""v"\""
        }

        rIns[i]=v
    }

    for(i in rOuts) {
        v=rOuts[i]
        gsub("(^\"|')|(\"|'$)", "", v)
        vals[valI]=v
        rOuts[i]=valI
        valI++
    }

    rules[ruleI++]=join(rIns, ",")" > "join(rOuts, ",")
}

END {
    # print "" > "/dev/stderr"

    # print "- ins -----" > "/dev/stderr"
    # for(i in ins) {
    #     print i " " ins[i] > "/dev/stderr"
    # }
    # print " " > "/dev/stderr"

    # print "- outs -----" > "/dev/stderr"
    # for(i in outs) {
    #     print i " " outs[i] > "/dev/stderr"
    # }
    # print " " > "/dev/stderr"

    # print "- rules -----" > "/dev/stderr"
    # for(i in rules) {
    #     print i " " rules[i] > "/dev/stderr"
    # }
    # print " " > "/dev/stderr"

    # print "- vals -----" > "/dev/stderr"
    # for(i in vals) {
    #     print i " " vals[i] > "/dev/stderr"
    # }
    # print " " > "/dev/stderr"
    
    asVars(ins, inVars)
    print "case \"" join(inVars, "¬") "\" in" 

    for(ruleI in rules) {
        split(rules[ruleI], parts, / *> */)
        split(parts[1], rIns, / *, */)
        split(parts[2], rOuts, / *, */)

        printf "  "
        for(i in ins) {
            if(i > 1) { printf "¬" }

            v=rIns[i]
            if(v) { printf "%s",v }
            else  { printf "*" }
        }
        print ")"

        for(i in rOuts) {
            if(outs[i]) {
                printf "    "
                print "@bindHeredoc "outs[i]" <<EOF"
                print vals[rOuts[i]]
                print "EOF"
            }
        }

        print "  ;;"
    }
    print "esac"
}

function join(array, sep,    notFirst, key, acc) {
    for(key in array) {
        acc=(acc)(notFirst ? sep : "")(array[key])
        notFirst=1
    }

    return acc
}

function asVars(inp, outp) {
    for(key in inp) {
        outp[key]="${"inp[key]"}"
    }
}
