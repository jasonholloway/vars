#!/bin/bash

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

outline_getIns() {
		local outline=$1
		local -n __ins=$2

		__ins=()

		if [[ $outline =~ ^.*\;(.*)\> ]]
		then
				readarray -t -d ',' __ins <<<"${BASH_REMATCH[1]}"
				a_trimAll __ins
		fi
}

outline_getOuts() {
		local outline=$1
		local -n __outs=$2

		__outs=()

		if [[ $outline =~ ^.*\;.*\>(.*)$ ]]
		then
				readarray -t -d ',' __outs <<<"${BASH_REMATCH[1]}"
				a_trimAll __outs
		fi
}





trim() {
		local -n __v="$1"
    __v="${__v#"${__v%%[![:space:]]*}"}"
    __v="${__v%"${__v##*[![:space:]]}"}"   
}

a_trimAll() {
		local -n __a=$1
		local i
		
		for i in ${!__a[*]}
		do trim __a[$i]
		done
}

main() {
	check "can unpack outline ins" <<-'EOF'
		@RUN=
		  ins=()
		  outline_getIns "A; in1,in2 > out1" ins
		@AFTER=
		  [[ ${#ins[*]} -eq 2 ]] || fail not enough ins
			a_has ins in1 || fail missing in1
			a_has ins in2 || fail missing in2
	EOF

	check "can unpack outline outs" <<-'EOF'
		@RUN=
		  outs=()
		  outline_getOuts "A; in1,in2 > out1,out2" outs
		@AFTER=
		  [[ ${#outs[*]} -eq 2 ]] || fail not enough outs
			a_has outs out1 || fail missing out1
			a_has outs out2 || fail missing out2
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



fail() {
		echo "@FAIL $*"
}

a_has() {
		local -n __a=$1
		local val=$2
		local v

		for v in "${__a[@]}"
		do
				if [[ $v == $val ]]
				then return 0
				fi
		done

		return 1
}


check() {
		local name="$1"
		echo "? ${name}:"

		{
				local -A vars=()

				gather vars
				local run="${vars[RUN]}"
				local input="${vars[INPUT]}"
				local expect="${vars[EXPECT]}"
				local after="${vars[AFTER]}"
				local ok=1

				gather vars < <(
						echo "@RESULT="
						eval "$run" <<<"$input"

						echo "@CHECK1="
						eval "$after"
				)

				local result="${vars[RESULT]}"

				local type rest
				while read -r type rest
				do
						case $type in
								@FAIL)
										ok=
										echo "Failed: $rest"
								;;
								@LOG)
										echo "$rest"
								;;
						esac
				done <<<"${vars[CHECK1]}"

				if [[ $ok ]]; then echo SUCCESS!!!; fi
		} | sed 's/^/  /'


		# {
		# 		if [[ $result == $expect ]]; then
		# 				echo *PASSED*
		# 		else
		# 				echo *FAILED*
		# 				diff --color=always <(echo "$expect") <(echo "$result")
		# 		fi
		# 		echo
		# } | sed 's/^/  /'

}

gather() {
		local -n __vars=$1
		local -a acc=()
		local vn=_

		while read -r line
		do
				
				if [[ $line =~ ^@([A-Z0-9]+)=$ ]]
				then
						__vars[$vn]=$(IFS=$'\n'; echo "${acc[*]}")
						vn=${BASH_REMATCH[1]}
						acc=()
				else
						acc+=("$line")
				fi
		done

		__vars[$vn]=$(IFS=$'\n'; echo "${acc[*]}")
}

main
