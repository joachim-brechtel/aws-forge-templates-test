#!/bin/bash
set -e

if [[ "${APP_DATA_FS_TYPE}" = "zfs" ]]; then
    echo "Installing ZFS"

    # Because we're not able to run on the latest Kernel, we need to manually install the 
    # sources to avoid pulling down the latest (and incompatible) sources transitively.
    # This can be removed when we unlock the version, which should be possible when ZFS on Linux 6.5.10 is released.
    sudo yum install --releasever=2016.09 -y "kernel-devel-$(uname -r)"

    sudo yum localinstall -y --nogpgcheck http://download.zfsonlinux.org/epel/zfs-release.el6.noarch.rpm
    sudo gpg --quiet --with-fingerprint /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux
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
