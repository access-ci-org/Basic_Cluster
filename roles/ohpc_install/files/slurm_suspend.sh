#!/bin/bash

nodes=`scontrol show hostnames $1`

echo "$(date) Suspend invoked: $0 $@" >> /var/log/slurm_power.log

for node in $nodes
do
  ipmitool -I lanplus -U admin -P adminpass -H $node-idrac power off
done
