#!/bin/bash

[[ $__LIB_OUTLINE ]] || source lib/outline.sh 
[[ $__LIB_CHECK ]] || source lib/check.sh 


check "outline roundtrip" <<-'EOF'
		outline_create o "v:A" "a:in1{x=3} in2" "a:out1 out2"
		outline_write o str
		outline_read o2 n:str
	.,
		chk o2 eq "A; in1{x=3},in2 > out1,out2"
EOF

check "outline roundtrip with rest" <<-'EOF'
		outline_read o "v:A; in{x} > out {hello}"
		parp outline_write o
	.>
		A; in{x} > out {hello}
EOF

check "outline roundtrip with rest empty" <<-'EOF'
		outline_read o "v:A; in{x} > out {}"
		parp outline_write o
	.>
		A; in{x} > out {}
EOF

check "outline roundtrip without rest" <<-'EOF'
		outline_read o "v:A; in{x} > out"
		parp outline_write o
	.>
		A; in{x} > out
EOF

check "outline_getRest" <<-'EOF'
		outline_read o "v:blah:/A/B/C|12,123123213; in{x} > out {wibble}" 
		parp outline_getRest o
	.>
		wibble
EOF

check "outline_setRest" <<-'EOF'
		outline_create o "v:blah:/A/B/C|12,123123213" "a:in1{x}" "a:out1" 
		outline_setRest o "v:blahblahblah"
		parp outline_write o
	.>
		blah:/A/B/C|12,123123213; in1{x} > out1 {blahblahblah}
EOF

check "outline_setRest 2" <<-'EOF'
		outline_read o "v:blah:/A/B/C|12,123123213; in{x} > out {blah}" 
		outline_setRest o "v:moo"
		parp outline_write o
	.> 
		blah:/A/B/C|12,123123213; in{x} > out {moo}
EOF


check "outline_getBid" <<-'EOF'
		outline_create o "v:blah:/A/B/C|12,123123213" "a:in1 in2" "a:out1" 
		outline_getBid o bid
	.,
		chk bid == "blah:/A/B/C|12,123123213"
EOF

check "outline_setBid" <<-'EOF'
		outline_create o "v:blah:/A/B/C|12,123123213" "a:in1 in2" "a:out1" 
		outline_setBid o "v:wibble:blah,123"
	.,
		chk o == "wibble:blah,123; in1,in2 > out1"
EOF

check "outline_setIns 1" <<-'EOF'
		outline_read o "v:A; in1,in2 > out1"
		outline_setIns o "a:in3 in4"
	.,
		chk o == "A; in3,in4 > out1"
EOF

check "outline_setIns 2" <<-'EOF'
		outline_read o "v:A; in1,in2 > out1"
		outline_setIns o "a:"
	.,
		chk o == "A; > out1"
EOF

check "outline_setOuts" <<-'EOF'
		outline_read o "v:A; in1,in2 > out1"
		outline_setOuts o "a:out3 out4"
	.,
		chk o == "A; in1,in2 > out3,out4"
EOF

check "outline_getIns" <<-'EOF'
		outline_read o "v:A; in1,in2 > out1" 
		outline_getIns o ins
	.,
		chk ins hasLen 2
		chk ins has in1
		chk ins has in2
EOF

check "outline_getOuts" <<-'EOF'
		outline_read o "v:A; in1,in2 > out1,out2" 
		outline_getOuts o outs
	.,
		chk outs hasLen 2
		chk outs has out1
		chk outs has out2
EOF

