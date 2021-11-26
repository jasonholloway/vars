#!/bin/bash

[[ $__LIB_CHECK ]] || source ${VARS_PATH}/lib/check.sh 
[[ $__LIB_STACK ]] || source ${VARS_PATH}/lib/stack.sh 

check "stack read/write" <<-'EOF'
		nosh stack_read s <<-EOL
				 elephant
				 chimpanzee
		EOL

		parp stack_write s
	.>
		elephant
		chimpanzee
EOF

check "stack read from ref" <<-'EOF'
		v=hello

		stack_read s n:v

		parp stack_write s
	.>
		hello
EOF

check "stack stuff" <<-'EOF'
		stack_push s v:aardvark
		stack_push s v:badger
		stack_push s v:chinchilla

		parp stack_write s
	.>
		chinchilla
		badger 
		aardvark 
EOF

check "stack push pop" <<-'EOF'
		stack_push s v:aardvark
		stack_push s v:badger
		stack_push s v:chinchilla
		stack_pop s popped

		parp stack_write s
	.>
		badger
		aardvark 
	.,
		chk popped eq chinchilla
EOF
