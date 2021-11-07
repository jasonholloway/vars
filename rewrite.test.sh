#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_REWRITE ]] || source lib/rewrite.sh 

main() {
	check "rewrite pass thru" <<-'EOF'
			outline="blah:/A/B/C|12,123123213; in1,in2 > out1" 
		  outline_getBid outline bid
		.,
		  chk bid == "blah:/A/B/C|12,123123213"
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
