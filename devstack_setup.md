# How to DevStack

> This is for running devstack on Ubuntu 16.04 as of September 9, 2016, (near the end of Newton)

This was tested using VMWare Fusion 8.1.1 on OSX.
An alternative is VirtualBox. Download VirtualBox latest 4.xx https://www.virtualbox.org/wiki/Download_Old_Builds_4_3
Download Ubuntu 16.04 http://releases.ubuntu.com/16.04/ubuntu-16.04-desktop-amd64.iso
Create a Ubuntu VM, 64 bit. Give it 4-6 GB RAM, 25-40 GB HD, 2-3 processors
Boot up the VM, install ubuntu, use the default settings.

1. Get the latest update sources

```
sudo apt-get update
```

> ONLY IF USING VIRTUAL BOX! Needed for making ubuntu full screen (i.e.; install guest additions) # Then mount guest additions ISO via virtualbox window and run the installation script

```
sudo apt-get install dkms
sudo apt-get install -y build-essential linux-headers-server
```

1. update one last time

```
sudo apt-get update -y
sudo apt-get upgrade -y
```

1. pull down requirements

```
sudo apt-get install git curl vim git-review
```

1. clone devstack

```
cd ~
git clone https://github.com/openstack-dev/devstack
cd devstack
```

1. create a file called local.conf

```
vi local.conf
```

1. Add the following to the file

```
[[local|localrc]]
RECLONE=yes
OFFLINE=no

DATABASE_PASSWORD=openstack
ADMIN_PASSWORD=openstack
SERVICE_PASSWORD=openstack
RABBIT_PASSWORD=openstack

# keystone
ENABLED_SERVICES=rabbit,mysql,key
# horizon
ENABLED_SERVICES+=,horizon
# nova
ENABLED_SERVICES+=,n-api,n-crt,n-cpu,n-cond,n-sch,n-obj,n-novnvc
# glance
ENABLED_SERVICES+=,g-api,g-reg
# cinder
ENABLED_SERVICES+=,cinder,c-api,c-vol,c-sch,c-bak
# uncomment the line below if you want nova-net, you probably don't
#ENABLED_SERVICES+=,n-net
# neutron
ENABLED_SERVICES+=,q-agt,q-dhcp,q-l3,q-meta,q-metering,q-svc,quantum
# swift
#ENABLED_SERVICES+=,s-account,s-container,s-object,s-proxy
#SWIFT_REPLICAS=1
#SWIFT_HASH=011688b44136573e209e

LOGFILE=/opt/stack/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=True
SCREEN_LOGDIR=/opt/stack/logs
```

1. Now run devstack!

```
./stack.sh
```

1. Source your generated RC file:

```
. openrc admin admin
```

1. Run some commands

```
openstack user list
```

1. Make sure that you can access horizon, launch firefox and go to: localhost and authenticate with admin/openstack

1. Check your processes by checking `screen`:

```
screen -r   # launches the screen
```

> bring up log switcher: `ctrl + a`, then double quote
> exit screen: `ctrl + a`, then 'd' for disconnect

# Setting up dev environment

1. Install a few things for testing...

```
sudo apt-get install python2.7-dev python3-dev -y
sudo pip install tox
```

1. Set up git

```
git config --global user.name "Steve Martinelli"
git config --global user.email "s.martinelli@gmail.com"
```

1. Set up gerrit

```
git config --global --add gitreview.username "stevemar"
```

1. Setup git-review & gerrit

```
ssh-keygen
# Confirm the default path .ssh/id_rsa
# Enter a passphrase, leave it blank.
cat ~/.ssh/id_rsa.pub
# the key will be printed out 
# copy and paste that key into gerrit
# in gerrit - go to top right, settings > keys > add new key
```
