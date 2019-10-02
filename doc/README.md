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

The XCBC project is designed to provide the basic software necessary to create
and HPC environment similar to that found on XSEDE resources, with open-source 
software and a minimum of fuss. 

We use the OpenHPC repositories (link) for setup of the cluster management
software and scheduler.

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

1\.  Configure the network interfaces on the
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


For the compute nodes, define two virtual machines, 'compute-0' and 'compute-1' with
the boot order (Under 'Settings->General') set to Network ONLY, and a single ethernet
interface, on the internal network. DO NOT INSTALL ANYTHING ON THESE VMs - The images 
will be generated and pushed out from the headnode during this tutorial. Make sure they have 
at least 2GB of RAM - otherwise the disk images built in this tutorial will be too large,
and you will encounter mysterious errors.

Building the Cluster
====================

Installation of the base OS on the headnode
-------------------------------------------

1\. Install CentOS 7.x minimal, on the headnode VM, 

During installation, the default partition setup is fine.
It helps to set up the three network interfaces at this point. 
Don't touch the 'NAT' interface, other than to check the 'Always Connect' box under
'Configure->General'. The same goes for the 'host-only' network.

Configure the internal network interface to have address 10.0.0.1, netmask /24 and gateway 
0.0.0.0 - the headnode will act as router for the compute nodes.

/24 is important, so that Warewulf will see the compute nodes as existing on
the same network as the headnode interface!!! Don't forget to also check the
'Always Connect' box.


2\. After installation, check the ip of your headnode on the host-only adapter via

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

You may also need to ensure that the connections will autoconnect on reboot:

      nmcli con modify $internal-nic connection.autoconnect=yes
      nmcli con modify $public-nic connection.autoconnect=yes

(replace enp0s3 with each of your interfaces! The host-only and internal network 
interfaces are the most likely to have this turned off by default.)

Connecting to your headnode
---------------------------

Instead of using the VirtualBox terminal, it's often much simpler to ssh in to the headnode
from your native local terminal - which allows for copy-pasting, window history, etc. 

Check the address of the host-only network using the ```ip addr``` command on the
headnode - usually in the ```192.168.56.0/24``` by default.

From your host machine, open a terminal emulator, and you should be able to ssh in as 
root (using the password you set during install - running ```ssh-copy-id root@$headnode_ip```
is also quite useful, if you're on a Linux host machine.).

Follow the guide below from your local terminal, rather than the VirtualBox terminal.
(primarily for ease of use)

Installation of the XCBC Tools and Dependencies
-----------------------------------------------

####Please note - this is meant to be run as the root user!

0\. ```yum install git vim bash-completion```

Git is necessary for getting the
playbooks; vim and bash-completion are just nice add-ons. Install your
editor of choice!

1\. `git clone https://github.com/XSEDE/CRI_XCBC/ `

  Get the actual playbooks.

This creates a directory named `CRI_XCBC` in your current directory, which
contains the XCBC Ansible playbooks.

2\. On the headnode, from your ${HOME} directory, 
run `ssh-keygen`, to create a local set of ssh keys, followed by 

`cat .ssh/id_rsa.pub >> .ssh/authorized_keys`


3\. ```cd ./CRI_XCBC``` and then run the ```install_ansible.sh``` script.

 The script creates a python virtualenv named “ansible” in
 ```${HOME}/ansible_env/ansible```, in order to avoid polluting
 the system python installation. The ansible source code is cloned into
 ```${HOME}/ansible_env/ansible_source```.

### Prepare your shell session

The next two steps prepare your shell for using the ansible playbooks,
by source two files containing environment variables - one for a
python virtualenv, and one for the local installation of ansible.

4\. `source ${HOME}/ansible_env/ansible/bin/activate`

Loads the ansible virtualenv into the current session.

5\. `source ${HOME}/ansible_env/ansible_source/hacking/env-setup `

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
    of the current openhpc release rpm. 

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

#### Private network parameters
No changes are necessary in this section.
These are the default parameters used for the private network that is
used to communicate with/between the compute nodes. The compute_ip parameters
define the range over which the dhcp server on the headnode will offer
IP addresses.

If you change the subnet here, make sure to do so consistently! The 
network_mask (CIDR mask) and network_long_netmask must cover the same subnet,
and the compute_ip limits must fall within the same subnet.

-    ```private_network: "10.0.0.0"```
-    ```private_network_mask: "24"```
-    ```private_network_long_netmask: "255.255.255.0"```
-    ```compute_ip_minimum: "10.0.0.2"```
-    ```compute_ip_maximum: "10.0.0.255"```


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
    in `CRI_XCBC/roles/gpu_build_vnfs/files/`.
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
-   ```compute_chroot: centos7-compute```
-   ```gpu_chroot_loc: "/opt/ohpc/admin/images/{{ gpu_chroot }}"```
-   ```gpu_chroot: centos7-gpu```
-   ```login_chroot_loc: "/opt/ohpc/admin/images/{{ login_chroot }}"```
-   ```login_chroot: centos7-login```

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

Ansible Inventory
-----------------

Note the inventory file in
```CRI_XCBC/inventory```:
```
[headnode]
headnode ansible_host="{{ headnode_private_ip }}" ansible_connection=ssh ansible_ssh_user=root
```

Make sure that the hostname of your headnode matches the entry on that line! Either
edit the inventory file, or change the hostname via:
```hostnamectl set-hostname headnode```.

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

1\. 
This first role installs necessary dependencies for the OpenHPC rpms,
configures the firewall zones `internal` and `public`. This also installs
fail2ban, configures the `/etc/hosts` file, and sets up the headnode
as an ntp server for the cluster (this is IMPORTANT for SLURM functionality).
This also configures ssh to disallow password authentication - if you 
don't want this, edit the template in
`roles/pre_ohpc/templates/sshd_config.j2`
To apply this role, run:
`ansible-playbook -i inventory/headnode -t pre_ohpc headnode.yml`

2\. `ansible-playbook -i inventory/headnode -t ohpc_install headnode.yml`
This second role installs several OpenHPC package groups, `base, warewulf
and slurm server`, configures SLURM (and enables job accounting), creates
a basic template for the compute nodes, and applies two fixes to the 
wwsh and wwnodescan scripts.

3\. `ansible-playbook -i inventory/headnode -t ohpc_config headnode.yml`
This third role configures the headnode for several things. It sets the 
interface that Warewulf uses, and sets up httpd to serve files to compute
nodes. It configures xinetd for tftp (for PXE-booting the compute nodes),
and mariadb for the internal Warewulf database. This also initializes the 
NFS exports from the headnode to compute nodes, in `/etc/exports`. There are three
main exports:
- `/home` for user home directories
- `/opt/ohpc/public` for OpenHPC documentation and packages
- `/export' for custom software packages shared to compute nodes

Installation of the compute nodes
---------------------------------

4\. `ansible-playbook -i inventory/headnode -t compute_build_vnfs headnode.yml `
This role builds an image for the compute nodes, by configuring a chroot environment
in `/opt/ohpc/admin/images/centos-7.3-compute`, and adding a "VNFS" image to the Warewulf
database. This will be used by the compute nodes to PXE boot.
It takes a while to build the image - good time to take a break from your screen!

5\. `ansible-playbook -i inventory/headnode -t compute_build_nodes headnode.yml `
This role does one of two things: if you are using the automatic inventory method, 
it runs wwnodescan, with names based on the number of nodes you've defined in 
`group_vars/all`, and waits for the nodes to boot. At this point, simply `Start` your 
compute nodes in VirtualBox, without providing a boot medium, and watch to be sure
they receive a DHCP response. Occasionally, they will fail to receive a response, but 
will work fine if booted a second time. 

If you are using the 'manual' method of node entry, this role will enter the provided
information (again, from `group_vars/all`) in the Warewulf database. At that point, you
may boot your compute nodes any time after the role finishes running, and they should
receive a PXE boot image from the headnode as in the automatic method.

6\. `ansible-playbook -i inventory/headnode -t nodes_vivify headnode.yml`
This final role will "bring your nodes to life" by starting the necessary services 
on the headnode and compute nodes, such as slurmctld (on the headnode), 
slurmd (on the compute nodes), and munge (used by slurm on all nodes for 
authentication).

Testing the scheduler 
---------------------
After confirming that both nodes have booted successfully (In the VirtualBox windows,
you should see a basic login prompt for each), double-check that you are able to
ssh into the machines as root. 

Now, in order to test the scheduler, it is necessary to add a user, by running
`useradd testuser` on the headnode.
To make sure the new user will be enabled on the compute node, run
`wwsh file sync` to update the passwd,group, and shadow files in the Warewulf
database, followed by 
`pdsh -w compute-[0-1] '/warewulf/transports/http/wwgetfiles'`
to request that the compute nodes pull the files from the master. While they are automatically
synced every 5 minutes, this will force an update immediately.

Next, become the new user, via `su - testuser`.


Open your text editor of choice, and create a (very) simple slurm batch file
(named `slurm_ex.job` in this example), like:
```
#!/bin/sh
#SBATCH -o nodes.out
#SBATCH -N 2

/bin/hostname
srun -l /bin/hostname
srun -l /bin/pwd
```

Submit this to the scheduler via
`sbatch ./slurm_ex.job`

You should receive a message like `Submitted batch job 2` and find an output
file called `nodes.out` with the contents:
```
[testuser@headnode ~]$ cat nodes.out 
compute-0
0: compute-0
1: compute-1
0: /home/testuser
1: /home/testuser
```

Otherwise, there should be useful debugging information in /var/log/slurmctld 
on the headnode, or in /var/log/slurmd on the compute nodes. 

Conclusion
==========

At this point, you have a basic working cluster with scheduler. The addition of scientific
software and utilities available through XSEDE will be covered in this guide soon.

Thanks for trying this out! Please get in touch with any problems, questions, or comments
at help@xsede.org, with 'XCRI XCBC Tutorial" in the subject line.
