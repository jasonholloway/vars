BEGIN {
    ruleI=0
    heredoc=0
    heredocText=""
}

# start heredoc
/^ *[;:].*<<EOF$/ {
    gsub("^\\s*[;:]\\s*", "")
    gsub("<<EOF$", "")
    heredocText=$0
    heredoc=1
    next
}

# end heredoc
heredoc!=0 && /^EOF/ {
    rules[ruleI++]=heredocText
    heredocText=""
    heredoc=0
    next
}

# continue heredoc
heredoc!=0 {
    if(heredoc == 1) {
        heredocText = heredocText $0
    }
    else {
        heredocText = heredocText"\n"$0
    }
    
    heredoc++
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
}

# rule
/^ *[;:]/ {
    gsub("^\\s*[;:]\\s*", "")
    rules[ruleI++]=$0
}

END {
    asVars(ins, inVars)
    print "case \"" join(inVars, "¬") "\" in" 

    for(ruleI in rules) {
        split(rules[ruleI], parts, / *> */)
        split(parts[1], ruleIns, / *, */)
        split(parts[2], ruleOuts, / *, */)

        printf "  "
        for(i in ins) {
            if(i > 1) { printf "¬" }

            v=ruleIns[i]
            if(v) { printf "%s",v }
            else  { printf "*" }
        }
        print ")"

        for(k in ruleOuts) {
            printf "    "
            print "@bind "outs[k]" \""ruleOuts[k]"\""
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
