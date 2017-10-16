#!/bin/bash

set -e

nodes=`scontrol show hostname $1`

echo "$(date) Resume invoked - $0 $@" >> /var/log/slurm_power.log

for node in $nodes
do
# BE SURE TO CHANGE YOUR PASSWORDS HERE, OR CREATE AN ALIAS!
  power_state=$(ipmitool -I lanplus -U admin -P adminpass -H $node-idrac power status)
  echo "Node $node has power state: $power_state" >> /var/log/slurm_power.log
  if [[ $power_state =~ "off" ]]; then
    echo "powering node on" >> /var/log/slurm_power.log
    ipmitool -I lanplus -U admin -P adminpass -H $node-idrac power on
  fi
  echo "Done with initial loop" >> /var/log/slurm_power.log
done

#env >> /var/log/slurm_power.log
#echo $$ >> /var/log/slurm_power.log

for node in $nodes
do
  initial_boot=$(awk '/BootTime/ {print $0}' <(scontrol show node $node))
  echo "CHECKING VIA SCONTROL: $node" >> /var/log/slurm_power.log
  #node_status=$(scontrol show node $node) 
  node_status=$(awk '/BootTime/ {print $0}' <(scontrol show node $node))
  echo "Initial boot time $initial_boot" >> /var/log/slurm_power.log
  echo "First scontrol check done $node_status" >> /var/log/slurm_power.log
#  until [[ $node_status =~ "unexpectedly rebooted" ]]; do
  until [[ $inital_boot != $node_status ]]; do
    echo "Entered scontrol check loop" >> /var/log/slurm_power.log
#   echo "CHECKING VIA SCONTROL:"
    sleep 5
    node_status=$(awk '/BootTime/ {print $0}' <(scontrol show node $node))
#    node_status=$(scontrol show node $node) 
#   echo "Node check: $node_status"
  done
done

#echo "Final scontrol" >> /var/log/slurm_power.log
#scontrol update nodename=$1 state=idle >> /var/log/slurm_power.log
echo "ALL DONE" >> /var/log/slurm_power.log
