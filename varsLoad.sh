#!/bin/bash

p=${1:?need parallelism value}
shift 

b=${1:?need block}
shift

. vars prep $b

for i in $(seq 1 $p); do
	LOAD_ID=$i vars run $b &
done

wait
