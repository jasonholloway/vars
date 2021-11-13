#!/bin/bash

[[ $__LIB_OUTLINE ]] || source lib/outline.sh 
[[ $__LIB_CHECK ]] || source lib/check.sh 


check "outline roundtrip" <<-'EOF'
		ol_create o "v:A" "a:in1{x=3} in2" "a:out1 out2"
		ol_write o str
		ol_read o2 n:str
	.,
		chk o2 eq "A; in1{x=3},in2 > out1,out2"
EOF

check "outline roundtrip with rest" <<-'EOF'
		ol_read o "v:A; in{x} > out {hello}"
		parp ol_write o
	.>
		A; in{x} > out {hello}
EOF

check "outline roundtrip with rest empty" <<-'EOF'
		ol_read o "v:A; in{x} > out {}"
		parp ol_write o
	.>
		A; in{x} > out {}
EOF

check "outline roundtrip without rest" <<-'EOF'
		ol_read o "v:A; in{x} > out"
		parp ol_write o
	.>
		A; in{x} > out
EOF

check "ol_getRest" <<-'EOF'
		ol_read o "v:blah:/A/B/C|12,123123213; in{x} > out {wibble}" 
		parp ol_getRest o
	.>
		wibble
EOF

check "ol_setRest" <<-'EOF'
		ol_create o "v:blah:/A/B/C|12,123123213" "a:in1{x}" "a:out1" 
		ol_setRest o "v:blahblahblah"
		parp ol_write o
	.>
		blah:/A/B/C|12,123123213; in1{x} > out1 {blahblahblah}
EOF

check "ol_setRest 2" <<-'EOF'
		ol_read o "v:blah:/A/B/C|12,123123213; in{x} > out {blah}" 
		ol_setRest o "v:moo"
		parp ol_write o
	.> 
		blah:/A/B/C|12,123123213; in{x} > out {moo}
EOF


check "ol_getBid" <<-'EOF'
		ol_create o "v:blah:/A/B/C|12,123123213" "a:in1 in2" "a:out1" 
		ol_getBid o bid
	.,
		chk bid == "blah:/A/B/C|12,123123213"
EOF

check "ol_setBid" <<-'EOF'
		ol_create o "v:blah:/A/B/C|12,123123213" "a:in1 in2" "a:out1" 
		ol_setBid o "v:wibble:blah,123"
	.,
		chk o == "wibble:blah,123; in1,in2 > out1"
EOF

check "ol_setIns 1" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1"
		ol_setIns o "a:in3 in4"
	.,
		chk o == "A; in3,in4 > out1"
EOF

check "ol_setIns 2" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1"
		ol_setIns o "a:"
	.,
		chk o == "A; > out1"
EOF

check "ol_setOuts" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1"
		ol_setOuts o "a:out3 out4"
	.,
		chk o == "A; in1,in2 > out3,out4"
EOF

check "ol_getIns" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1" 
		ol_getIns o ins
	.,
		chk ins hasLen 2
		chk ins has in1
		chk ins has in2
EOF

check "ol_getOuts" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1,out2" 
		ol_getOuts o outs
	.,
		chk outs hasLen 2
		chk outs has out1
		chk outs has out2
EOF

check "ol unpack" <<-EOF
		ol_unpack "v:A; in1,in2 > out1" bid ins outs
	.,
		chk bid eq A
		chk ins has in1
		chk ins has in2
		chk outs has out1
EOF

check "ol pack" <<-EOF
		parp 'ol_pack "v:A" "a:in1{wibble} in2" "a:out1"'
	.>
		A; in1{wibble},in2 > out1
EOF

