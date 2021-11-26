#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_LINK ]] || source lib/link.sh 

check "link read n write" <<-'EOF'
		link_read l "v:0,2;"
		parp link_write l
	.>
		0,2
EOF

check "link add supplier" <<-'EOF'
		link_init l
		link_addSupplier l v:Z
		link_addSupplier l v:A
		link_addSupplier l v:Z
		parp link_write l
	.>
		A,Z
EOF
