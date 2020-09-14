#!/bin/sh
dnf -y install epel-release
dnf -y install python38-devel python38-setuptools gcc libffi-devel openssl-devel python38-pip
pip3 install virtualenv
mkdir -p $HOME/ansible_env
cd $HOME/ansible_env
python3 -m virtualenv ansible
source $HOME/ansible_env/ansible/bin/activate 
git clone --single-branch --branch stable-2.9 https://github.com/ansible/ansible.git --recursive ./ansible_source
#pexpect has to be 3.3 because new 4.01 version only
# works with python >= 2.7 :(
pip3 install paramiko PyYAML Jinja2 httplib2 six pexpect
#moved this after lib installations
source $HOME/ansible_env/ansible_source/hacking/env-setup -q
## later figure out how to source it together with virtualenv
#echo -e "\nsource $HOME/ansible/hacking/env-setup -q" >> $HOME/.activate_ansible
# run a quick test 
echo "# Ansible Inventory" > inventory
echo "[headnode]" >> inventory
echo "localhost ansible_connection=local" >> inventory
ansible -i inventory headnode -a 'hostname'
