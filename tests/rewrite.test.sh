#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_REWRITE ]] || source lib/rewrite.sh 

main() {
	check "rewrite pass thru" <<-'EOF'
			rewrite
		.<
			A; ip{site=sorted} > sortedIp
			B; url > ip
			C; site,country > url
			D; > site
			E; > country
		.>
			A; ip{site=sorted} > sortedIp
			B; url > ip
			C; site,country > url
			D; > site
			E; > country
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
