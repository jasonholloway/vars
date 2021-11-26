#!/bin/bash

[[ $__LIB_CHECK ]] || source ${VARS_PATH}/lib/check.sh 
[[ $__LIB_REWRITE ]] || source ${VARS_PATH}/lib/rewrite.sh 

check "forms links" <<-'EOF'
		ols_ingest

		parp A_write_ordered links
	.<
		A; pig{sex=male+breed=Duroc},pig{sex=female+breed=Tamworth} > piglet {}
		B; farm,sex > pig {}
		C; breed > farm {}
	.> :s :d
		 farm>2,pig>1,piglet>0
EOF


xcheck "summon supplier" <<-'EOF'
		ols_ingest

		ols_rewrite a:piglet

	.<
		A; pig{sex=male+breed=Duroc},pig{sex=female} > piglet {}
		B; farm,sex > pig {}
		C; breed > farm {}
	.> :s :d
		0
		breed farm pig sex
		A; pig{sex=male+breed=Duroc},pig{sex=female} > piglet {breed,farm,pig,sex}
		B; farm,sex > pig {breed,farm,sex}
		C; breed > farm {breed}
EOF

# masks are filled
# that's pure positive unquestionable value right there
# and with this in place we can go to town with the pinning propagation

# then pinnings are to be propagated on top, but only if mask says yes
# 
#







xcheck "propagates pins through outlines" <<-'EOF'
		ols_ingest
		ols_propagatePins a:sortedIp
	.<
		A; ip{site=sorted},msg > sortedIp
		B; url > ip
		C; country,site{type=mobile} > url
		D; > site
		E; > country
		F; > msg
	.> :s
		A; ip{site=sorted},msg > sortedIp  {}
		B; url > ip                        {}
		C; country,site{type=mobile} > url {}
		D; > site                          {}
		E; > country                       {}
		F; > msg                           {}
		B; url > ip                        {site=sorted}
		C; country,site{type=mobile} > url {site=sorted}
		E; > country                       {site=sorted}
		D; > site                          {site=sorted+type=mobile}
EOF

xcheck "propagates pins" <<-'EOF'
		ols_ingest
		ols_propagatePins a:piglet
	.<
		A; pig{sex=male+breed=Duroc},pig{sex=female+breed=Tamworth} > piglet {}
		B; farm,sex > pig {}
		C; breed > farm {}
	.> :s
		A; pig{sex=male+breed=Duroc},pig{sex=female+breed=Tamworth} > piglet {}
		B; farm,sex > pig {}
		C; breed > farm {}
		B; farm,sex > pig {breed=Duroc+sex=male}
		C; breed > farm {breed=Duroc+sex=male}
		B; farm,sex > pig {breed=Tamworth+sex=female}
		C; breed > farm {breed=Tamworth+sex=female}
EOF

# long and short is we need to walk up the tree 
# filling up necessary vars
# which could be done independently of propagating pins
# except - with the pins we duplicate;
# the known vars are stone cold facts
#
# do the known vars should actually be done first...
# then with the pins we copy out
# 

xcheck "applies pins" <<-'EOF'
		ols_ingest
		ols_applyPins
	.<
		A; pig{sex=male+breed=Duroc},pig{sex=female+breed=Tamworth} > piglet {}
		B; farm,sex > pig {}
		C; breed > farm {}
		B; farm,sex > pig {breed=Duroc+sex=male}
		C; breed > farm {breed=Duroc+sex=male}
		B; farm,sex > pig {breed=Tamworth+sex=female}
		C; breed > farm {breed=Tamworth+sex=female}
	.> :s
		A; pig{sex=male+breed=Duroc},pig{sex=female+breed=Tamworth} > piglet {}
		B; farm{breed=Duroc},sex{sex=male} > pig{breed=Duroc+sex=male} {}
		C; breed{breed=Duroc} > farm{breed=Duroc} {}
		B; farm{breed=Tamworth},sex{sex=female} > pig{breed=Tamworth+sex=female} {}
		C; breed{breed=Tamworth} > farm{breed=Tamworth} {}
EOF

xcheck "example join" <<-'EOF'
		ols_propagatePins a:lead
	.<
		A; dog{name=Boris},owner{eyes=blue} > lead
		B; taste > dog,owner
	.> :s :d
		TODO
EOF
# ABOVE JOIN ONLY COMES INTO PLAY AFTER ols_cullPins


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
