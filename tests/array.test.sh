#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_ARRAY ]] || source lib/array.sh

check "array reverse" <<-'EOF'
		a_read a "v:a b c d e"
		a_reverse a
		parp a_write a
	.>
		e d c b a
EOF

check "array reverse single item" <<-'EOF'
		a_read a "v:a"
		a_reverse a
		parp a_write a
	.>
		a
EOF

check "array reverse empty" <<-'EOF'
		a_read a "v:"
		a_reverse a
		parp a_write a
	.>

EOF

check "array reverse with offset" <<-'EOF'
		a_read a "v:a b c d e"
		a_reverse a 2
		parp a_write a
	.>
		a b e d c
EOF

check "a_copy" <<-'EOF'
		a=(a b c d)
		a_copy a b
	.,
		chk b[0] eq a
		chk b[1] eq b
		chk b[2] eq c
		chk b[3] eq d
EOF
