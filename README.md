Simple playbooks to install OpenHPC version 1.0 using Ansible. 

Primarily, this was useful for learning more about Ansible and OpenHPC; currently this will NOT work, as OpenHPC is rapidly developing. 

The Ansible layout is quite simple, since it consists of two flat playbooks, without using any of the nice features of roles.
For long-term projects, this is not advisable!

When this was working, the workflow was pretty much:

install ansible 
ansible-playbook OHPC_frontend_build.yml
ansible-playbook OHPC_add_computes.yml
 boot compute nodes when signalled

This results in a non-working Slurm config! The current OpenHPC may work better, now. 
There are some neat tricks in OHPC_add_computes for causing the playbook to wait until the compute nodes boot.
