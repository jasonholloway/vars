#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_STACKMAP ]] || source lib/stackMap.sh 

check "stackMap stuff" <<-'EOF'
    stackMap_init m

    stackMap_push m D 4
    stackMap_push m C 3
    stackMap_push m A 1
		stackMap_pop m _
		stackMap_pop m _
    stackMap_push m B 2

    # stackMap_ingest m "hamster=cheekimunki+chinchilla=Mark"

    # stackMap_pop m
    
    stackMap_print m
	.>
		B=2+D=4
EOF

check "stackMap read/write" <<-'EOF'
    stackMap_init m
    stackMap_read m "v:hamster=cheekimunki+chinchilla=Mark"
    parp stackMap_write m
	.>
		B=2+D=4
EOF

# todo
# read and write here...
