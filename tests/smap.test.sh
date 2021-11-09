#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_SMAP ]] || source lib/smap.sh 

check "smap read/write" <<-'EOF'
    smap_read m "v:hamster=Cheekimunki+chinchilla=Mark"
    parp smap_write m
	.>
	  chinchilla=Mark+hamster=Cheekimunki
EOF

check "smap read/write with push" <<-'EOF'
    smap_read m "v:hamster=Cheekimunki+chinchilla=Mark"
		smap_push m "v:aardvark=Aaron"
    parp smap_write m
	.>
	  aardvark=Aaron+chinchilla=Mark+hamster=Cheekimunki
	  chinchilla=Mark+hamster=Cheekimunki
EOF

check "smap stuff" <<-'EOF'
    smap_init m

    smap_push m "v:D=4"
    smap_push m "v:C=3"
    smap_push m "v:A=1"
		smap_pop m _
		smap_pop m _
    smap_push m "v:B=2"

		parp smap_write m
	.>
		B=2+D=4
		D=4
		C=3+D=4
		A=1+C=3+D=4
		C=3+D=4
		D=4
EOF
