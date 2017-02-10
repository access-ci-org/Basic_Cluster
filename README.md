Simple playbooks to install OpenHPC version 1.0 using Ansible. 

The Ansible layout is fairly simple, using a series of roles for different parts of the installation process. 

This will get you to the point of a working slurm installation across your cluster. It does not 
currently provide any scientific software or user management options! 

install ansible 
ansible-playbook -i inventory headnode.yml

Wait for the signal, and then boot your compute nodes! Provided everything is
wired correctly, network cards work, etc., this should lead to compute nodes
provisioned with a basic CentOS image.

These playbooks do NOT touch the compute nodes - though adding scientific applications
via Ansible will be an option in the future.
