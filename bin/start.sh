#!/bin/bash

for ((idx = 1; idx <= $1; idx++)); do
  stack exec raft -- -n $1 &
done
