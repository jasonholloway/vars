#!/bin/bash

[[ $__LIB_OUTLINE ]] || source lib/outline.sh 
[[ $__LIB_CHECK ]] || source lib/check.sh 

check "outline_getBid" <<-'EOF'
		outline="blah:/A/B/C|12,123123213; in1,in2 > out1" 
		outline_getBid outline bid
	.,
		chk bid == "blah:/A/B/C|12,123123213"
EOF

check "outline_setBid" <<-'EOF'
		outline="blah:/A/B/C|12,123123213; in1,in2 > out1" 
		bid="wibble:blah"
		outline_setBid outline bid
	.,
		chk outline == "wibble:blah; in1,in2 > out1"
EOF

check "outline_setIns 1" <<-'EOF'
		newIns=(in3 in4)
		outline="A; in1,in2 > out1"
		outline_setIns outline newIns
	.,
		chk outline == "A; in3,in4 > out1"
EOF

check "outline_setIns 2" <<-'EOF'
		newIns=()
		outline="A; in1,in2 > out1"
		outline_setIns outline newIns
	.,
		chk outline == "A; > out1"
EOF

check "outline_setOuts" <<-'EOF'
		outs=(out3 out4)
		outline="A; in1,in2 > out1"
		outline_setOuts outline outs
	.,
		chk outline == "A; in1,in2 > out3,out4"
EOF

check "outline_getIns" <<-'EOF'
		ins=()
		outline="A; in1,in2 > out1" 
		outline_getIns outline ins
	.,
		chk ins hasLen 2
		chk ins has in1
		chk ins has in2
EOF

check "outline_getOuts" <<-'EOF'
		outs=()
		outline="A; in1,in2 > out1,out2" 
		outline_getOuts outline outs
	.,
		chk outs hasLen 2
		chk outs has out1
		chk outs has out2
EOF
