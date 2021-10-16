#!/bin/bash

main() {
    parseIns "blah booo:woo{v1=neigh,v2=baa} yip"
}


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# TODO
# - input mappings to be stored as metadata against blocks (blocks.sh) which then need to be used by deducer and runner - necessary and isolatable work
# - deducer (1st visit) to extract var roots from needles
# - deducer (2nd visit) rewrite confluents with needles
#
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# but rewriting will rely on injecting input and output mappings - so we need these to be functional first
# input mappings first pls (but also output ones)
# mappings are not to do with outlines, but with the runnable body
# both ins and outs can have mappings specified in their expressions

parseIns() {
    local w p
    for w in $@
    do
				if [[ $w =~ ^(([a-zA-Z0-9_-]+):)?([a-zA-Z0-9_-]+)(\{(.*)\})?$ ]]
				then
						echo "matched ${BASH_REMATCH[3]}" >&2

						echo "  shimInto ${BASH_REMATCH[2]}" >&2

						local IFS=,
						for e in ${BASH_REMATCH[5]}
						do
								echo "  injectPin $e" >&2
						done
				else
						echo FAIL $w >&2
				fi

				echo >&2
    done
}

main "$@"
