Basic Description
=================

This is a basic quickstart guide for the CentOS 7 version of the XSEDE
Compatible Basic Cluster, based on the OpenHPC Project.
(https://openhpc.community). It covers initial setup of your hardware
(or virtual machines), configuration options for the ansible scripts,
and a brief walkthrough of how to use the scripts.

The provided scripts are designed to be able to provision three types of
nodes: basic compute nodes, login nodes, and GPU nodes.

By the end of the guide, you should have a working cluster with running
Slurmctld, which can accept and run jobs on all nodes.

If you encounter errors, have questions, suggestions, or comments,
please contact the XCRI Team by emailing help@xsede.org. Be sure to ask
for the XCRI team!

Initial Setup On VirtualBox
===========================

Create (at least) two VM’s - one to be the headnode, and one to be a
compute node.

For the headnode, activate three network interfaces, attached to NAT,
Internal Network, and Host-only. (For hardware you would require only
two, but having both NAT and host-only simplifies configuration on the
headnode.)

1\. Install CentOS 7.x, on the headnode VM, and run ‘yum update‘ to get
to the latest version. 2. Configure the network interfaces on the
headnode. For host-only, something like:

        nmcli connection add con-name main-host type ethernet \ 
         ifname enp0s9 ip4 192.168.56.99 gw4 192.156.56.1
        nmcli connection modify main-host ipv4.never-default TRUE
        nmcli connection up main-host

This is for an ssh connection into the main host. You could also use
this as the interface for the headnode in an ansible inventory file, and
run these roles against the headnode remotely. 3. Configure the network
interface on for the internal “private” network.

        nmcli connection add con-name internal type ethernet \ 
         ifname enp0s9 ip4 10.0.1.1/16 gw4 10.0.1.1

/16 is important, so that WW will see the compute nodes as existing on
the same network as the headnode interface!!!

        nmcli connection modify internal ipv4.never-default TRUE
        nmcli connection up internal

After defining the interfaces, ensure that the private nic is set in the
internal firewall zone, and that the public is set in the public
firewall zone.

      nmcli connection modify internal connection.zone internal
      nmcli connection modify public connection.zone public

Initial Setup On Hardware
=========================

1\. Make sure you have at least two network interfaces on the headnode.

2\. Install CentOS 7.x, run ‘yum update‘ to get to the latest version. It
might be useful to set up a main OS partition, and serarate /home and
/export partitions, to mimic the case in which these are mounted from
SAN devices.

3\. Make sure the public and private network interfaces are configured.
See above for hints on nmcli.

Building the Cluster
====================

Initial headnode setup
----------------------

0\. yum install git vim bash-completion git is necessary for getting the
playbooks; vim and bash-completion are just nice add-ons. Install your
editor of choice!

1\. `git clone https://github.com/XSEDE/CRI_XCBC/ `

  Get the actual playbooks.

2\. `./OHPC\_Ansible/install_ansible.sh `

  This may fail due to frequently
 changing dependency requirements in python libraries. The script creates
 a python virtualenv named “ansible” in
 \$<span>HOME</span>/ansible\_env/ansible, in order to avoid polluting
 the system python installation. The ansible source code is cloned into
 \$<span>HOME</span>/ansible\_env/ansible\_source.

3\. `source \$<span>HOME</span>/ansible_env/ansible/bin/activate `

Loads the ansible virtualenv into the current session.

4\. `source
\$<span>HOME</span>/ansible\_env/ansible_source/hacking/env-setup `

Loads the ansible environment variables into the current session.

Defining Cluster Parameters
---------------------------

Examine the file OHPC\_Ansible/group\_vars/all. This file contains
several important parameters for the cluster installation. The current
defaults should mostly work with the virtualbox configuration suggested
above.

-   openhpc\_release\_rpm: - this contains the version number and path
    of the current openhpc release rpm. Older versions are listed and
    commented out. generate the list of these via

        curl -s https://github.com/openhpc/ohpc/releases/ | grep rpm | grep -v sles | grep -v strong | sed 's/.*="\(.*\)".*".*".*/\1/'

-   public\_interface: - the device name of the public NIC on the
    headnode

-   private\_interface - the device name of the private NIC on the
    headnode

-   cluster\_name - the name you’d like to give your cluster. This will
    be inserted into the slurm.conf file.

-   gres\_types (if any GPU nodes exist) - any types of consumable
    resources that exist on your cluster.

-   stateful\_nodes \# MAKE THIS WORK - choose whether or not you’d like
    to build stateful compute nodes, or go with the Warewulf default of
    having nodes pull down a new image each time they boot.

-   nvidia\_driver\_installer (if relevant) - contains the full name of
    the NVIDIA driver installer. This should be downloaded and placed
    in OHPC\_Ansible/roles/gpu\_build\_vnfs/files/.

-   node-inventory-method - auto or manual \# MAKE THIS WORK - allows
    one to switch between ’manually’ adding compute node information
    here (in group\_vars/all) or by running wwnodescan.
    Currently non-functional.

node-inventory section:

-   compute\_nodes: - this is a list of dictionaries, each of which
    contains the necessary information on each compute node. You will
    have to edit the MAC address for each node, if using the
    manual node-inventory-method.

-   login\_nodes: - list of login nodes, same format as compute\_nodes

-   gpu\_nodes: - list of gpu nodes, with the addition of a key
    describing the number and types of GPU available on that node. These
    parameters will be inserted into the slurm.conf.

Running the Ansible Scripts
---------------------------

Examine the headnode.yml file - this contains the basic recipe for the
sequence of steps to take. While it could be run all at once with
‘ansible-playbook headnode.yml‘ we will take go through it here step by
step. Each step can be run with the ’-t’ flag, which asks
ansible-playbook to exectute only tasks with the given name.

When running these scripts, be sure to either cd to the playbook 
directory (`cd ${HOME}/CRI_XCBC/`) or provide the complete path
before each file - like
`ansible-playbook -i ${HOME}/CRI_XCBC/inventory/headnode 
-t pre_ohpc ${HOME}/CRI_XCBC/headnode.yml`.

0\. On the headnode, run ssh-keygen, followed by cat .ssh/id\_rsa.pub
&gt;&gt; .ssh/authorized\_keys

1\. `ansible-playbook -i inventory/headnode -t pre_ohpc headnode.yml`

2\. `ansible-playbook -i inventory/headnode -t ohpc_install headnode.yml`
explain

3\. `ansible-playbook -i inventory/headnode -t ohpc_config headnode.yml`
explain

4\. `ansible-playbook -i inventory/headnode -t compute_build_vnfs headnode.yml `
- Now is the time to grab a cup of coffee

5.5 Edit the compute inventory file!!! - wwnodescan will be an option
soon!

6\. `ansible-playbook -i inventory/headnode -t compute_build_nodes headnode.yml `
explain

7\. Boot the compute nodes!

\# slurmctld failed b/c: \# chrony was not started on the headnode
correctly \# - just a peril of a VM \# - forgot to run wwsh file sync
after adding the new node. \# - slurmd didn’t start b/c of bad
slurm.conf
