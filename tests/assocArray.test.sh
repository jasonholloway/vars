#!/bin/bash

[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh 
[[ $__LIB_CHECK ]] || source lib/check.sh 

check "read assocArray" <<-'EOF'
		declare -A a=()
		A_read a "A>1,B>2"
	.,
		chk a[A] eq 1
		chk a[B] eq 2
EOF

check "print assocArray" <<-'EOF'
		declare -A a=([woo]=13 [blah]=7)
		printed=$(A_print a)

		declare -A b=()
		A_read b "$printed"
	.,
		chk b[blah] eq 7
		chk b[woo] eq 13
EOF
