#!/bin/bash
set -e

if [[ "${APP_DATA_FS_TYPE}" = "zfs" ]]; then
    echo "Installing ZFS"

    # Because we're not able to run on the latest Kernel, we need to manually install the 
    # sources to avoid pulling down the latest (and incompatible) sources transitively.
    # This can be removed when we unlock the version, which should be possible when ZFS on Linux 6.5.10 is released.
    sudo yum install -y "kernel-devel-$(uname -r)"

    wget http://download.zfsonlinux.org/epel/zfs-release.el6.noarch.rpm
    sudo rpm --import /tmp/RPM-GPG-KEY-zfsonlinux.key
    if sudo rpm -K zfs-release.el6.noarch.rpm | grep "NOT OK"; then
     echo "Could not verify signature of zfs-release package"
     exit 1
    fi
    sudo yum -y localinstall zfs-release.el6.noarch.rpm
    sudo yum install -y zfs
    sudo /sbin/modprobe zfs

    # Enable ZFS to start at boot
    echo "Enabling ZFS"
    sudo chkconfig zfs-import on
    sudo chkconfig zfs-mount on
    sudo chkconfig zfs-share on
    sudo chkconfig zfs-zed on
    echo "Finished installing ZFS"
fi