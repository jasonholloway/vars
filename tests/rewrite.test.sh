#!/bin/bash

[[ $__LIB_CHECK ]] || source lib/check.sh 
[[ $__LIB_REWRITE ]] || source lib/rewrite.sh 

check "rewrite pass thru" <<-'EOF'
		rewrite_expand a:sortedIp
	.<
		A; ip{site=sorted},msg > sortedIp
		B; url > ip
		C; site{type=mobile},country > url
		D; > site
		E; > country
		F; > msg
	.> :s :d
		A; ip{site=sorted},msg > sortedIp  {}
		B; url > ip                        {site=sorted}
		C; country,site{type=mobile} > url {site=sorted}
		D; > site                          {site=sorted+type=mobile}
		E; > country                       {site=sorted}
		F; > msg                           {}
EOF

xcheck "example join" <<-'EOF'
		rewrite_expand a:sortedIp
	.<
		A; dog{name=Boris},owner{eyes=blue} > lead
		B; taste > dog,owner
	.> :s
EOF

# above is a join; the two subtrees can be considered as separate
# though in the case above, we would want consistency in the supply,
# else Boris dog may be supplied for brown-eyed owner
# in this case, we want to pin the upstream context conistently:
# we want the same pins on both sides
# will be done by using a separate pin statement covering the whole block
# per-var pins like the above are selectively used for their precise meaning
# implying separation.
#
#




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
