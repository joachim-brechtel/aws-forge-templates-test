#!/bin/bash
set -e

if [[ "${APP_DATA_FS_TYPE}" = "zfs" ]]; then
    echo "Installing ZFS"

    sudo yum localinstall -y --nogpgcheck http://archive.zfsonlinux.org/epel/zfs-release.el6.noarch.rpm

    sudo gpg --quiet --with-fingerprint /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux
    sudo yum install -y zfs

    # Enable ZFS to start at boot
    echo "Enabling ZFS"
    sudo chkconfig zfs-import on
    sudo chkconfig zfs-mount on
    sudo chkconfig zfs-share on
    sudo chkconfig zfs-zed on
    echo "Finished installing ZFS"
fi