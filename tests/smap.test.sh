#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_SMAP ]] || source lib/smap.sh 

check "smap read/write" <<-'EOF'
    smap_read m "v:hamster=Cheekimunki+chinchilla=Mark"

    parp smap_write m
	.>
	  chinchilla=Mark+hamster=Cheekimunki
EOF

check "smap read/write multiline" <<-'EOF'
    nosh smap_read m <<EOL
			hamster=Cheekimunki+chinchilla=Mark
			chinchilla=Mark
		EOL

    parp smap_write m
	.>
	  chinchilla=Mark+hamster=Cheekimunki
		chinchilla=Mark
EOF

check "smap peek" <<-'EOF'
    nosh smap_read m <<EOL
			hamster=Cheekimunki+chinchilla=Mark
			hamster=Cheekimunki
			mouse=Nippy
		EOL

		# parp smap_write m >&2

    parp smap_peek m
	.>
	  chinchilla=Mark+hamster=Cheekimunki
EOF

check "smap pop peek" <<-'EOF'
    nosh smap_read m <<EOL
			hamster=Cheekimunki+chinchilla=Mark
			hamster=Cheekimunki
			mouse=Nippy
		EOL

		# echo $m__count "${m[*]}" >&2
		parp smap_pop m
    parp smap_peek m
    parp smap_peek m
		parp smap_pop m
    parp smap_peek m
	.>
		chinchilla=Mark+hamster=Cheekimunki
	  hamster=Cheekimunki
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
	  chinchilla=Mark+hamster=Cheekimunki
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
