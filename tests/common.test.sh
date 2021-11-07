#!/bin/bash

[[ $__LIB_COMMON ]] || source lib/common.sh 
[[ $__LIB_CHECK ]] || source lib/check.sh 

check "reads arg nameref exps" <<-'EOF'
		wibble=hello
		arg_read "n:wibble" v
	.,
		chk v eq "hello"
EOF

check "reads arg value exps" <<-'EOF'
		arg_read "v:123" v
		arg_read "v:123:456" y
	.,
		chk v eq 123
		chk y eq "123:456"
EOF

check "reads arg array exps" <<-'EOF'
		arg_read "a:A B C" v
	.,
		chk v has A
		chk v has B
		chk v has C
		chk v hasLen 3
EOF
