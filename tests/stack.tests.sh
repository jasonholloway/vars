#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_STACK ]] || source lib/stack.sh 

check "stack stuff" <<-'EOF'
		stack_init s
		stack_push s aardvark
		stack_push s badger
		stack_push s chinchilla
		parp stack_write s
	.>
		aardvark badger chinchilla
EOF

check "stack push pop" <<-'EOF'
		stack_init s
		stack_push s aardvark
		stack_push s badger
		stack_push s chinchilla
		stack_pop s popped
		parp stack_write s
	.>
		aardvark badger
	.,
		chk popped eq chinchilla
EOF
