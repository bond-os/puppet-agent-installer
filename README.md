# Puppet Agent Installer

As I work in multiple environments with all sorts of CentOS, Ubuntu and OS X machines, I needed a fast and easy way for installing puppet agent on them, so this script happened.

This script downloads proper packages for operating system in which it is executed, installs them, creates puppet.conf file with master hostname entered, ensures service startup and starts the service. It can be used to install latest packages for puppet 3.x branch or puppet 4.x (released in puppet collection packages - note, that this is not tested well enough).

## Compatibility

Tested with puppet 3x on:
* Ubuntu 14.04 LTS
* Ubuntu 16.04 LTS
* OS X 10.11 El Capitan (work in progress)


## Todo
* test on CentOS systems 6.x and 7.x
* test with puppet 4.x (puppet collection 1)

## Usage

To install puppet agent on node, use:

```
curl -sL https://github.com/bond-os/puppet-agent-installer/raw/master/install.sh | bash -s puppet-master-address [1]
```

Installer script takes two arguments, first is the hostname/ip address of puppet master to connect to, second argument tells the script to install puppet from Puppet Collection 1 (puppet >3). Leave empty for installation of puppet 3.x.
