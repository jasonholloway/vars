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

check "read assocArray with nameref and syms" <<-'EOF'
    local -A x=()
    raw="hamster=Cheekimunki+chinchilla=Mark"
    A_read x "n:raw" '+' '='
	.,
		chk x[chinchilla] eq Mark
		chk x[hamster] eq Cheekimunki
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

check "A_merge" <<-'EOF'
		declare -A x=([woof]=1 [baa]=2 [moo]=3 [neigh]=4 [squeak]=5 [oink]=6)
		declare -A y=([bleat]=7 [baa]=8 [howl]=9)

		A_merge x y

		parp A_write_ordered x
	.>
		baa>8,bleat>7,howl>9,moo>3,neigh>4,oink>6,squeak>5,woof>1
EOF
