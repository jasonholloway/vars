#!/bin/bash

[[ $__LIB_OUTLINE ]] || source lib/outline.sh 
[[ $__LIB_CHECK ]] || source lib/check.sh 

check "ol_getBid" <<-'EOF'
		ol_create o "v:blah:/A/B/C|12,123123213" "a:in1 in2" "a:out1" 
		ol_getBid o bid
	.,
		chk bid == "blah:/A/B/C|12,123123213"
EOF

check "ol_setBid" <<-'EOF'
		ol_create o "v:blah:/A/B/C|12,123123213" "a:in1 in2" "a:out1" 
		ol_setBid o "v:wibble:blah,123"
		parp ol_getBid o
	.>
		wibble:blah,123
EOF


check "outline roundtrip" <<-'EOF'
		ol_read o "v: A; in1{x=3},in2 > out1,out2 {moo}"
		parp ol_write o
	.>
		A; in1{x=3},in2 > out1,out2 {moo}
EOF

check "outline roundtrip with rest empty" <<-'EOF'
		ol_read o "v:A; in{x} > out {}"
		parp ol_write o
	.>
		A; in{x} > out {}
EOF

check "outline roundtrip without rest normalizes" <<-'EOF'
		ol_read o "v:A; in{x} > out"
		parp ol_write o
	.>
		A; in{x} > out {}
EOF


check "ol_getRest" <<-'EOF'
		ol_read o "v:blah:/A/B/C|12,123123213; in{x} > out {wibble}" 
		parp ol_getRest o
	.>
		wibble
EOF

check "ol_setRest" <<-'EOF'
		ol_create o "v:blah:/A/B/C|12,123123213" "a:in1{x}" "a:out1" "v:moo"
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

check "ol_setIns 1" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1"
		ol_setIns o "a:in3 in4"
		parp ol_write o
	.>
		A; in3,in4 > out1 {}
EOF

check "ol_setIns 2" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1"
		ol_setIns o "a:"
		parp ol_write o
	.>
		A; > out1 {}
EOF

check "ol_setOuts" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1 {ahoy}"
		ol_setOuts o "a:out3 out4"
		parp ol_write o
	.>
		A; in1,in2 > out3,out4 {ahoy}
EOF

check "ol_setOuts no rest" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1"
		ol_setOuts o "a:out3 out4"
		parp ol_write o
	.>
		A; in1,in2 > out3,out4 {}
EOF

check "ol_getIns" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1 {moo}" 
		ol_getIns o ins
	.,
		chk ins hasLen 2
		chk ins has in1
		chk ins has in2
EOF

check "ol_getIns no rest" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1" 
		ol_getIns o ins
	.,
		chk ins hasLen 2
		chk ins has in1
		chk ins has in2
EOF

check "ol_getOuts" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1,out2 {moo}" 
		ol_getOuts o outs
	.,
		chk outs hasLen 2
		chk outs has out1
		chk outs has out2
EOF

check "ol_getOuts no rest" <<-'EOF'
		ol_read o "v:A; in1,in2 > out1,out2" 
		ol_getOuts o outs
	.,
		chk outs hasLen 2
		chk outs has out1
		chk outs has out2
EOF

check "ol unpack" <<-EOF
		ol_unpack "v:A; in1,in2 > out1 {neigh}" bid ins outs rest
	.,
		chk bid eq A
		chk ins has in1
		chk ins has in2
		chk outs has out1
		chk rest eq neigh
EOF

check "ol pack" <<-EOF
		parp 'ol_pack "v:A" "a:in1{wibble} in2" "a:out1" "v:moo"'
	.>
		A; in1{wibble},in2 > out1 {moo}
EOF

check "ol pack 2" <<-EOF
		local -a ins=(in1 in2)
		local -a outs=(out1 out2)
		parp 'ol_pack "v:A" "na:ins" "na:outs" "v:moo"'
	.>
		A; in1,in2 > out1,out2 {moo}
EOF

