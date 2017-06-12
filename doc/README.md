Introduction
============

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

XCBC Overview
=============

The XCBC project is blah. 

We use the OpenHPC repositories (link) for setup of the cluster management
software and blah.

Ansible is used in this toolkit to provide an idempotent, non-invasive method
of managing the cluster headnode. Ideally, the admin installing the cluster
will only have to customize a single file before running the included 
playbooks. This guide walks the user through the cluster build by actually
running the ansible playbooks locally on the headnode, but this could
be done from a different machine just as easily, with a few tweaks to the
inventory file. We did not wish to force the reader to make changes
to some local machine, and so elected to keep everything on the VMs built 
specifically for this guide.

All of the (intended) customizable variables exist in the '''group_vars/all'''
file, which is described in more detail below (Section 3: Defining Cluster Parameters)

The installation process, at a high level, takes place in six phases:
(ignoring hardware/VM setup)
1\. Installation of the bare OS on the headnode
2\. Installation of the XCBC toolkit scripts and dependencies
3\. Defining cluster parameters
4\. Configuration of the headnode via Ansible
5\. Installation of the compute nodes
6\. Testing the scheduler 

This guide in particular will walk through the steps of building an XCBC using
VMs defined in VirtualBox, though this generalizes very well to a bare-metal
deployment as well.

Common Acronyms and Abbreviations
=================================

XCBC = XSEDE Compatible Basic Cluster

XNIT = XSEDE National Integration Toolkit

WW = Warewulf - the cluster management software preferred in the OpenHPC
 project.

VM = Virtual Machine

NIC = Network Interface Card

NAT = Network Address Translation - used by Virtualbox to provide
 a connection from the Headnode VM to the outside world.
 
OS = Operating System

HPC = High Performance Computing/Cluster/Computer

Initial Setup On VirtualBox
===========================

Create (at least) two VM’s - one to be the headnode, and one to be a
compute node.

For the headnode, activate three network interfaces, attached to NAT,
Internal Network, and Host-only. (For hardware you would require only
two, but having both NAT and host-only simplifies configuration on the
headnode.)

In this configuration, the assumption is that there is a host-only network
on Virtualbox configured with the internal DHCP server on. 
(Under File-\>Preferences-\>Networking-\>Host-only Networks).
The default network is 192.168.56.0, but feel free to change this as you 
prefer.

1\. Configure the network interfaces on the
headnode. There are three: one for NAT, which provides connection to the 
outside world, one for a host-only network,
and one for the internal network, which connects to
compute nodes.

The host-only network is for an ssh connection into the main host. You could also use
this as the interface for the headnode in an ansible inventory file, and
run these roles against the headnode remotely. 
Use the DHCP server provided by Virtualbox; you will find the ip address given to
the VM after installation of the OS. It is possible to use a static IP, but
this is somewhat unreliable on successive reboots or image copies.

Configure the internal network interface to have address 10.0.0.1, netmask /24 and gateway 
10.0.0.1 - the headnode will act as router for the compute nodes.

/24 is important, so that Warewulf will see the compute nodes as existing on
the same network as the headnode interface!!!

Building the Cluster
====================

Installation of the base OS on the headnode
-------------------------------------------

1\. Install CentOS 7.x minimal, on the headnode VM, and run ‘yum update‘ to get
to the latest version. 

Check the ip of your headnode on the host-only adapter via

      ip addr

Compare the MAC addresses of the interfaces on your headnode with those listed
in Virtualbox, to be sure you substitute the correct device names below!
(Typically, they show up as something like enp0s3,enp0s8, etc. - it pays to
double-check!)

The NAT ip address will be used sparingly in the following documentation, but will
be called ```$public-nic```. Virtualbox assigns these as 10.0.x.15, where x begins
at 2 for the 1st VM, 3 for the 2nd, etc.

Save the ip address of the interface on the host-only network - 
you'll use this as the address for the headnode in the ansible scripts, 
and it will be referred to as ```$host-nic```

The ip address for the internal nic was set earlier, and will be referred to 
either as 10.0.0.1 or ```$internal-nic```

Make sure that the host-only and internal adapters are not set as default
routes - ```ip route show``` should not list them as default! 
If you do see this, something like ```ip route del default via 10.0.0.1```
should do the trick, along with editing 'DEFROUTE=no' in 
the relevant ```/etc/sysconfig/network-scripts/ifcfg-``` file.

After checking the interfaces, ensure that the private nic is set in the
internal firewall zone, and that the public is set in the public
firewall zone.

      nmcli connection modify $internal-nic connection.zone internal
      nmcli connection modify $public-nic connection.zone public


Installation of the XCBC Tools and Dependencies
-----------------------------------------------

0\. ```yum install git vim bash-completion```
Git is necessary for getting the
playbooks; vim and bash-completion are just nice add-ons. Install your
editor of choice!

1\. `git clone https://github.com/XSEDE/CRI_XCBC/ `

  Get the actual playbooks.

This creates a directory named `CRI_XCBC` in your current directory, which
contains the XCBC Ansible playbooks.

2\. ```cd ./CRI_XCBC``` and then run the ```install_ansible.sh``` script.

 The script creates a python virtualenv named “ansible” in
 ```${HOME}/ansible_env/ansible```, in order to avoid polluting
 the system python installation. The ansible source code is cloned into
 ```${HOME}/ansible_env/ansible_source```.

### Prepare your shell session

The next two steps prepare your shell for using the ansible playbooks,
by source two files containing environment variables - one for a
python virtualenv, and one for the local installation of ansible.

3\. `source ${HOME}/ansible_env/ansible/bin/activate`

Loads the ansible virtualenv into the current session.

4\. `source ${HOME}/ansible_env/ansible_source/hacking/env-setup `

Loads the ansible environment variables into the current session.

Defining Cluster Parameters
---------------------------

Inside the ```CRI_XCBC``` directory, examine the file ```group_vars/all```. 
This file contains
several important parameters for the cluster installation. The current
defaults should work with the Virtualbox configuration suggested
above. This is the only file that should be edited during this tutorial!
Other files that would be useful or necessary to edit during a production
build will be pointed out as we go along.


(The format here is
-   ```parameter_name: default_value```

    description
)

Separated by category, the full list of parameters is:

#### OpenHPC Release Version
-   ```openhpc_release_rpm: "https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm"```

    This contains the version number and path
    of the current openhpc release rpm. Older versions are listed and
    commented out. generate the list of these via

        curl -s https://github.com/openhpc/ohpc/releases/ | grep rpm | grep -v sles | grep -v strong | sed 's/.*="\(.*\)".*".*".*/\1/'

#### Headnode Information
-   ```public_interface: enp0s3 ```
    
    The device name of the public NIC on the
    headnode (which provides access to the outside internet)

-   ```private_interface: enp0s9```

    The device name of the private NIC on the
    headnode, which gives access to the compute nodes 

-   ```headnode_private_ip: "10.0.0.1"```

    The ip of the headnode on the private network
 
-   ```build_kernel_ver: '3.10.0-327.el7.x86_64'```
    
    `uname -r` at build time - required for Warewulf to build bootstrap
    images for the compute nodes. THIS SHOULD BE UPDATED AT RUN-TIME!

#### slurm.conf variables
These are added to the SLURM configuration file as needed

-   ```cluster_name: "xcbc-example"```

    The name you’d like to give your cluster. This will
    be inserted into the slurm.conf file.

-   ```gres_types: "gpu" ```

    (if any GPU nodes exist) - any types of consumable
    resources that exist on your cluster. 
    COMMENTED OUT BY DEFAULT - IF YOU ARE BUILDING ON A PHYSICAL SYSTEM
    WITH GPU NODES, UNCOMMENT THIS LINE in ```${HOME}/CRI_XCBC/group_vars/all```!

#### Stateful Node controls
-   ```stateful_nodes: false```

    Choose whether or not you’d like
    to build stateful compute nodes, or go with the Warewulf default of
    having nodes pull down a new image each time they boot. 
    CURRENTLY NOT IMPLEMENTED, THE DEFAULT IS FALSE.

#Node Config Vars - for stateful nodes
-   ```sda1: "mountpoint=/boot:dev=sda1:type=ext3:size=500"```
-   ```sda2: "dev=sda2:type=swap:size=500"```
-   ```sda3: "mountpoint=/:dev=sda3:type=ext3:size=fill"```

    These options must be defined in order for compute nodes
    to boot from local disk. Currently outside the scope of this
    tutorial.

#### GPU Necessities
-   ```nvidia_driver_installer: "NVIDIA-Linux-x86_64-375.39.run"```

    Contains the full name of
    the NVIDIA driver installer. This should be downloaded and placed
    in `CRI_XCBC/roles/gpu\_build\_vnfs/files/`.
    COMMENTED OUT BY DEFAULT - ONLY NECESSARY FOR CLUSTERS WITH GPU
    NODES.

#### Warewulf Parameters
The following should not be changed, unless you are familiar with the guts
of these playbooks. They are used in defining the images for different
types of compute nodes, and must have corresponding names in the
directory defined by the ```template_path``` variable.

-   ```template_path: "/usr/libexec/warewulf/wwmkchroot/"```
-   ```compute_template: "compute-nodes"```
-   ```gpu_template: "gpu-nodes"```
-   ```login_template: "login-nodes"```

#### chroot Parameters
The following should not be changed, unless you are familiar with the guts
of these playbooks and are familiar with Warewulf. These define the location
and names of the chroot images for different types of compute nodes.
Do not worry! If you don't have GPU or login nodes, space and time will not
be wasted making unnecessary images.

-   ```compute_chroot_loc: "/opt/ohpc/admin/images/{{ compute_chroot }}"```
-   ```compute_chroot: centos7.3-compute```
-   ```gpu_chroot_loc: "/opt/ohpc/admin/images/{{ gpu_chroot }}"```
-   ```gpu_chroot: centos7.3-gpu```
-   ```login_chroot_loc: "/opt/ohpc/admin/images/{{ login_chroot }}"```
-   ```login_chroot: centos7.3-login```

#### Node Inventory Method
-   ```node_inventory_auto: true```

   Allows one to switch between ’manually’ adding compute node information
   here (in `${HOME}/CRI_XCBC/group_vars/all`) or by running wwnodescan.
   The default is to use wwnodescan to automatically search for nodes in
   the 10.0.0.0/24 network. In some situations, such as migrating an 
   existing cluster to a new framework, one may already have a list of
   hardware. If some of that is owned/provided by researchers, it is
   necessary to keep track of 'which nodes are which', and can be beneficial
   to add and name nodes based on an existing set of information.
   The following items are ONLY to be used in this case.

```
- compute_nodes: 
     - { name: "compute-1", vnfs: '{{compute_chroot}}',  cpus: 1, sockets: 1, corespersocket: 1,  mac: "08:00:27:EC:E2:FF", ip: "10.0.0.254"}
```

   The compute_nodes variable is a list of dictionaries, each of which
   contains the necessary information to build and name each compute node. You will
   have to edit the MAC address for each node, if using the
   manual node inventory method.

```
-   login_nodes: 
     - { name: "login-1", vnfs: '{{login_chroot}}', cpus: 8, sockets: 2, corespersocket: 4,  mac: "00:26:B9:2E:23:FD", ip: "10.0.0.2"}
```

   List of login nodes, same format as compute\_nodes

```
-   gpu_nodes: 
    - { name: "gpu-compute-1", vnfs: '{{gpu_chroot}}', gpus: 4, gpu_type: "gtx_TitanX", cpus: 16, sockets: 2, corespersocket: 8,  mac: "0C:B4:7C:6E:9D:4A", ip: "10.0.0.253"}
```

   List of gpu nodes, with the addition of a key
   describing the number and types of GPU available on that node. These
   parameters will be inserted into the slurm.conf. The gpu_type is completely custom, and is the
   string that users must request to run on these nodes in the default SLURM configuration.

Configuration of the Headnode via Ansible
-----------------------------------------

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

Installation of the compute nodes
---------------------------------

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

Testing the scheduler 
---------------------
