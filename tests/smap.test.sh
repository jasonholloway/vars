#!/bin/bash

[[ $__LIB_CHECK ]] || source ${VARS_PATH}/lib/check.sh 
[[ $__LIB_SMAP ]] || source ${VARS_PATH}/lib/smap.sh 

check "smap read/write" <<-'EOF'
    smap_read m "v:hamster=Cheekimunki+chinchilla=Mark"

    parp smap_write m
	.>
	  hamster=Cheekimunki+chinchilla=Mark
EOF

check "smap read/write multiline" <<-'EOF'
    nosh smap_read m <<EOL
			hamster=Cheekimunki+chinchilla=Mark
			chinchilla=Mark
		EOL

    parp smap_write m
	.>
	  hamster=Cheekimunki+chinchilla=Mark
		chinchilla=Mark
EOF

check "smap read array" <<-'EOF'
		smap_readArray m "a:apple orange pear"
		parp smap_write m
	.>
		apple=1+orange=1+pear=1
EOF

check "smap peek" <<-'EOF'
    nosh smap_read m <<EOL
			hamster=Cheekimunki+chinchilla=Mark
			hamster=Cheekimunki
			mouse=Nippy
		EOL

    parp smap_peek m
	.>
	  hamster=Cheekimunki+chinchilla=Mark
EOF

check "smap pop peek" <<-'EOF'
    nosh smap_read m <<EOL
			hamster=Cheekimunki+chinchilla=Mark
			hamster=Cheekimunki
			mouse=Nippy
		EOL

		parp smap_pop m
    parp smap_peek m
		parp smap_pop m
    parp smap_peek m
	.>
		hamster=Cheekimunki+chinchilla=Mark
		hamster=Cheekimunki
	  hamster=Cheekimunki
		mouse=Nippy
EOF

check "smap push from nil" <<-'EOF'
		smap_init m
		smap_push m "v:aardvark=Aaron"
		smap_push m "v:stoat=Simon"

    parp smap_write m
	.>
	  aardvark=Aaron+stoat=Simon
	  aardvark=Aaron
EOF

check "smap read/write with push" <<-'EOF'
		smap_init m
    smap_read m "v:hamster=Cheekimunki+chinchilla=Mark"
		smap_push m "v:aardvark=Aaron"

    parp smap_write m
	.>
	  aardvark=Aaron+chinchilla=Mark+hamster=Cheekimunki
	  hamster=Cheekimunki+chinchilla=Mark
EOF

check "smap stuff" <<-'EOF'
    smap_init m

    smap_push m "v:D=4"
		parp smap_peek m

    smap_push m "v:C=3"
		parp smap_peek m

    smap_push m "v:A=1"
		parp smap_peek m

		smap_pop m _
		parp smap_peek m

		smap_pop m _
		parp smap_peek m

    smap_push m "v:B=2"
		parp smap_peek m
	.>
		D=4
		C=3+D=4
		A=1+C=3+D=4
		C=3+D=4
		D=4
		B=2+D=4
EOF


check "smap peek extract" <<-'EOF'
    smap_init m
    smap_push m "v:B=2"
    smap_push m "v:A=1"

		local -A a
		smap_peekA m a

		local -A b
		smap_popA m b

		local -A c
		smap_peekA m c
	.,
		chk a[A] eq 1
		chk a[B] eq 2

		chk b[A] eq 1
		chk b[B] eq 2

		chk c[A] eq ''
		chk c[B] eq 2
EOF

check "smap pushA" <<-'EOF'
		declare -A A=([a]=1 [b]=2)

		smap_init m
		smap_pushA m A

		A[a]=3
		smap_pushA m A

		parp smap_write m
	.>
		a=3+b=2
		a=1+b=2
EOF

