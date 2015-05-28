#!/bin/bash
#
# provision-build.sh - Provision our openSUSE for building OpenXPKI
#
# Notes:
#
# - If /mirrors/opensuse-zypp exists, enable caching of downloaded RPMs


if [ -d /mirrors/opensuse-zypp ]; then
    zypper modifyrepo -k --all
fi

zypper refresh

zypper --non-interactive --quiet install \
    git-core make perl-Template-Toolkit perl-Config-Std gcc \
    libopenssl-devel gettext-tools expat libexpat-devel rpm-build

if [ ! -d ~vagrant/.rpmbuild ]; then
    mkdir -p ~vagrant/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
	chown -R vagrant.users ~vagrant/rpmbuild
fi

if [ ! -f ~vagrant/.rpmmacros ]; then
    echo '%_topdir %(echo $HOME)/rpmbuild' > ~vagrant/.rpmmacros
	chown vagrant.users ~vagrant/.rpmmacros
fi


