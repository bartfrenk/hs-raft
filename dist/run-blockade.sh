#!/bin/bash

containers=$(docker ps --format '{{.Names}}')

for c in $containers;
do
    if [[ "$c" =~ raft-[0-9]+ ]]; then
        blockade add "$c";
        echo "Added container $c to the blockade"
    fi
done;
