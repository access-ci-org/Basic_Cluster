#!/bin/sh
easy_install pip
#pexpect has to be 3.3 because new 4.01 version only
# works with python >= 2.7 :(
pip install paramiko PyYAML Jinja2 httplib2 six pexpect==3.3
#moved this after lib installations
git clone git://github.com/ansible/ansible.git --recursive
source ./ansible/hacking/env-setup -q
echo -e "\nsource ./ansible/hacking/env-setup -q" >> .bashrc
echo "# Ansible Inventory" > inventory
echo "[headnode]" >> inventory
echo "localhost ansible_connection=local" >> inventory
mkdir -p /etc/ansible
mv inventory /etc/ansible/hosts
./ansible/bin/ansible headnode -a "/bin/hostname"
