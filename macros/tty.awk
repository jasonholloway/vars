BEGIN {
    readingHeader=1
}

readingHeader && /^#/ {
    print
    next
} 

readingHeader {
    readingHeader=0
    print "{"
}

{ print }

END {
    print "} >\"$(tty)\""
}
