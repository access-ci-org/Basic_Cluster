#!/bin/sh
yum -y install epel-release
yum -y install python-devel python-setuptools python-setuptools-devel gcc libffi-devel openssl-devel ansible

# run a quick test 
echo "# Ansible Inventory" > tmp_inventory
echo "[headnode]" >> tmp_inventory
echo "localhost ansible_connection=local" >> tmp_inventory
ansible -i tmp_inventory headnode -a 'hostname'
rm tmp_inventory
