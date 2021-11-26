#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_SET ]] || source lib/set.sh 

check "set read write" <<-'EOF'
		set_read s "v:c,b,a"
		parp set_write s
	.>
		a,b,c
EOF

check "set read write with nums" <<-'EOF'
		set_read s "v:7,1,0"
		parp set_write s
	.>
		0,1,7
EOF

check "set add" <<-'EOF'
		set_init s
		set_add s v:z
		set_add s v:a
		set_add s v:z
		parp set_write s
	.>
		a,z
EOF

check "set add with nums" <<-'EOF'
		set_init s
		set_add s v:2
		set_add s v:1
		set_add s v:2
		parp set_write s
	.>
		1,2
EOF
