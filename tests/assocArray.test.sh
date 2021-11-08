#!/bin/bash

[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh 
[[ $__LIB_CHECK ]] || source lib/check.sh 

check "read assocArray" <<-'EOF'
		declare -A a=()
		A_read a "v:A>1,B>2"
	.,
		chk a[A] eq 1
		chk a[B] eq 2
EOF

check "print assocArray" <<-'EOF'
		declare -A a=([woo]=13 [blah]=7)
		printed=$(A_print a)

		declare -A b=()
		A_read b "v:$printed"
	.,
		chk b[blah] eq 7
		chk b[woo] eq 13
EOF

check "A_write_ordered" <<-'EOF'
		declare -A r=([woof]=1 [baa]=2 [moo]=3 [neigh]=4 [squeak]=5 [oink]=6)
		parp A_write_ordered r
	.>
		baa>2,moo>3,neigh>4,oink>6,squeak>5,woof>1
EOF
