#!/bin/bash

[[ $__LIB_OUTLINE ]] || source lib/outline.sh 
[[ $__LIB_ASSOCARRAY ]] || source lib/assocArray.sh 
[[ $__LIB_CHECK ]] || source lib/check.sh 

source ./rewrite.sh 

parseWriteRoundtrip() {
		local bid rest left right both
		
		while IFS=\; read -r bid sig rest
		do
				echo -n "$bid; "

				local -a ins=()
				local -a outs=()

				if [[ $sig =~ ([a-zA-Z0-9,{}=]*)[[:space:]]*\>[[:space:]]*([a-zA-Z0-9,{}=]*) ]]
				then
						readarray -t -d',' ins <<<"${BASH_REMATCH[1]}"
						readarray -t -d',' outs <<<"${BASH_REMATCH[2]}"
				fi
				
				local inString=$(IFS=','; echo -n "${ins[*]//$'\n'/}")
				local outString=$(IFS=','; echo -n "${outs[*]//$'\n'/}")

				local newSig="$inString > $outString"
				echo "${newSig# *}"
		done
}

main() {
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
		
	# check "parses writes parses" <<-EOF
	# 	@RUN=
	# 	  parseWriteRoundtrip
	# 	@INPUT=
	# 		A; ip{site=sorted} > sortedIp
	# 		B; url > ip
	# 		C; site,country > url
	# 		D; > site
	# 		E; > country
	# 	@EXPECT=
	# 		A; ip{site=sorted} > sortedIp
	# 		B; url > ip
	# 		C; site,country > url
	# 		D; > site
	# 		E; > country
	# EOF

	# check expandPins <<-EOF
	# 	@NAME=
	# 		outlines expanded
	# 	@INPUT=
	# 		A: ip{site=sorted} > sortedIp
	# 		B: url > ip
	# 		C: site,country > url
	# 		D: > site
	# 		E: > country
	# 	@EXPECT=
	# 		A: ip{site=sorted} > sortedIp {}
	# 		B: url > ip                   {site=sorted}
	# 		C: site,country > url         {site=sorted}
	# 		D: > site                     {site=sorted}
	# 		E: > country                  {site=sorted}
	# EOF

	# check count <<-EOF
	# 	@NAME=
	# 		blahdyblah
	# 	@INPUT=
	# 		hamster
	# 		rat
	# 		mouse
	# 	@EXPECT=
	# 		7
	# 		3
	# 		5
	# EOF

		
	# test rewrite <<-EOF
	# 	@NAME=
	# 			something
	# 	@INPUT=
	# 			A: ip{site=sorted} > sortedIp {}
	# 			B: url > ip                   {site=sorted}
	# 			C: site,country > url         {site=sorted}
	# 			D: > site                     {site=sorted}
	# 			E: > country                  {site=sorted}
	# 	@EXPECT=
	# 			blahblah
	# EOF
}

main
