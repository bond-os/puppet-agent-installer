#!/usr/bin/env bash

# use puppet-collection? this install puppet v4 and up
# if not, intsalls puppet version 3.x
REPO_PC=0

# set puppet master
PUPPET_MASTER_HOST="puppet"

PARAM_PM=$1
PARAM_PC_REPO=$2
INSTALL_DISTRIBUTION_PACKAGE=0
UBUNTU_HACK=0
PUPPET_ENABLE=0

function install_linux {

    if [[ ${INSTALL_DISTRIBUTION_PACKAGE} == 0 ]] ; then
        curl -o /tmp/puppet-package ${PACKAGE_URL}

        if [[ ! -f /tmp/puppet-package ]] ; then
            echo "Error downloading package"
            exit 2
        fi

        ${COMMAND_INSTALL} /tmp/puppet-package
        ${COMMAND_UPDATE}
    fi

	# workaround for ubuntu setting exit code, when START=no (default) is set after package install and start
    if [[ ${UBUNTU_HACK} == 1 ]] ; then
        ${COMMAND_INSTALL_PACKAGE} || true
    else
        ${COMMAND_INSTALL_PACKAGE}
    fi

    # upgrade config file
    echo '[main]
        logdir = /var/log/puppet
        rundir = /var/run/puppet
        ssldir = $vardir/ssl
        server = PUPPET_MASTER

    [agent]
        classfile = $vardir/classes.txt
        localconfig = $vardir/localconfig' > /etc/puppet/puppet.conf

    sed -i "s/PUPPET_MASTER/$PARAM_PM/g" /etc/puppet/puppet.conf

    if [[ ! -z ${SERVICE_ENABLE_FILE} ]] ; then
        if [[ -f ${SERVICE_ENABLE_FILE} ]] ; then
            sed -i "s/no/yes/g" ${SERVICE_ENABLE_FILE}
        fi
    fi

    ${SERVICE_AUTOSTART}

    if [[ ${PUPPET_ENABLE} == 1 ]] ; then
        puppet agent --enable
    fi

    service puppet restart
}

function install_osx {

    echo "OS X detected"

    curl -o /tmp/facter-latest.dmg "http://downloads.puppetlabs.com/mac/facter-latest.dmg"
    curl -o /tmp/hiera-latest.dmg "http://downloads.puppetlabs.com/mac/hiera-latest.dmg"
    curl -o /tmp/puppet-latest.dmg "http://downloads.puppetlabs.com/mac/puppet-latest.dmg"

    facter_mount=`hdiutil mount /tmp/facter-latest.dmg | grep Volumes | awk '{print $3}'`
    facter_pkg=`ls ${facter_mount} | grep pkg`

    installer -package ${facter_mount}/${facter_pkg} -target /

    hdiutil unmount ${facter_mount}

#    hiera_mount=`hdiutil mount /tmp/hiera-latest.dmg | grep Volumes | awk '{print $3}'`
#    hiera_pkg=`ls ${hiera_mount} | grep pkg`
#
#    installer -package ${hiera_mount}/${hiera_pkg} -target /
#
#    hdiutil unmount ${hiera_mount}

    puppet_mount=`hdiutil mount /tmp/puppet-latest.dmg | grep Volumes | awk '{print $3}'`
    puppet_pkg=`ls ${puppet_mount} | grep pkg`

    installer -package ${puppet_mount}/${puppet_pkg} -target /

    hdiutil unmount ${puppet_mount}

    rm -f /tmp/facter-latest.dmg
    rm -f /tmp/hiera-latest.dmg
    rm -f /tmp/puppet-latest.dmg

    # upgrade config file
    echo '[main]
    logdir = /var/log/puppet
    rundir = /var/run/puppet
    ssldir = $vardir/ssl
    server = PUPPET_MASTER

[agent]
    classfile = $vardir/classes.txt
    localconfig = $vardir/localconfig' > /etc/puppet/puppet.conf

    sed -i '' "s/PUPPET_MASTER/$PARAM_PM/g" /etc/puppet/puppet.conf

    echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>Label</key>
        <string>com.puppetlabs.puppet</string>
        <key>OnDemand</key>
        <false/>
        <key>ProgramArguments</key>
        <array>
                <string>/usr/bin/puppet</string>
                <string>agent</string>
                <string>--no-daemonize</string>
                <string>--logdest</string>
                <string>syslog</string>
                <string>--color</string>
                <string>false</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>ServiceDescription</key>
        <string>Puppet agent service</string>
        <key>ServiceIPC</key>
        <false/>
</dict>
</plist>' > /Library/LaunchDaemons/com.puppetlabs.puppet.plist

    chown root:wheel /Library/LaunchDaemons/com.puppetlabs.puppet.plist
    chmod 644 /Library/LaunchDaemons/com.puppetlabs.puppet.plist

    launchctl load /Library/LaunchDaemons/com.puppetlabs.puppet.plist
    launchctl start com.puppetlabs.puppet
}

set -e

if [[ ${PARAM_PC_REPO} == 1 ]] ; then
	REPO_PC=1
fi

if [[ ! -f /etc/os-release ]] ; then

	if [[ -f /etc/centos-release ]] ; then
		NAME="CentOS Linux"
		VERSION_ID="cat /etc/centos-release | cut -d" " -f3 | cut -d "." -f1"
	elif [[ "$OSTYPE" == "darwin"* ]] ; then
	    NAME="Darwin"
    else
        echo "No /etc/os-release or other supported *-release file, cannot proceed"
        exit 1
	fi
else
    . /etc/os-release
fi

case ${NAME} in
	"Ubuntu")
		. /etc/lsb-release

		if [[ ${REPO_PC} == 1 ]] ; then
			PACKAGE_URL="https://apt.puppetlabs.com/puppetlabs-release-pc1-${DISTRIB_CODENAME}.deb"
		else
			PACKAGE_URL="https://apt.puppetlabs.com/puppetlabs-release-${DISTRIB_CODENAME}.deb"
		fi

	    if [[ ${DISTRIB_CODENAME} == "xenial" ]] ; then
	  		if [[ ${REPO_PC} == 0 ]] ; then
	            INSTALL_DISTRIBUTION_PACKAGE=1
       	    fi
        fi

        if [[ ${DISTRIB_CODENAME} == "trusty" ]] ; then
            UBUNTU_HACK=1
        fi

	 	COMMAND_INSTALL="dpkg -i"
	 	COMMAND_UPDATE="apt-get update"
	 	COMMAND_INSTALL_PACKAGE="apt-get install puppet -y"
	 	SERVICE_ENABLE_FILE="/etc/default/puppet"
	    if [[ ${DISTRIB_CODENAME} == "xenial" ]] ; then
            PUPPET_ENABLE=1
        fi

        SERVICE_AUTOSTART="update-rc.d puppet defaults"

	 	install_linux
	;;
	"CentOS Linux")
		if [[ ${REPO_PC} == 1 ]] ; then
			PACKAGE_URL="https://yum.puppetlabs.com/puppetlabs-release-pc1-el-${VERSION_ID}.noarch.rpm"
		else
			PACKAGE_URL="https://yum.puppetlabs.com/puppetlabs-release-el-${VERSION_ID}.noarch.rpm"
		fi

		COMMAND_INSTALL="rpm -ivh"
		COMMAND_UPDATE="yum clean all"
		COMMAND_INSTALL_PACKAGE="yum install puppet -y"
		SERVICE_ENABLE_FILE=""
	 	SERVICE_AUTOSTART="chkconfig puppet on"

	 	install_linux
	;;
	"Darwin")
	    # osx
	    install_osx
	;;
	*)
		echo "System version $NAME not supported"
esac

