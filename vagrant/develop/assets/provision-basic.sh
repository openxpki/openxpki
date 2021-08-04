#!/bin/bash
# Basic Vagrant Box setup

. /vagrant/assets/functions.sh

VBOX="$1"

#
# Environment
#
touch /etc/environment

if ! $(grep -q OXI_TEST_SAMPLECONFIG_DIR /etc/environment); then
    echo "OXI_TEST_SAMPLECONFIG_DIR=/code-repo/config" >> /etc/environment
fi
# Read our configuration and the one written by previous (DB) provisioning scripts
while read def; do export $def; done < /etc/environment

#
# Install Virtualbox guest addins
#
install_vbox=0
if $(which VBoxService >/dev/null); then
    INSTALLED_VBOX=$(VBoxService --version | sed -r 's/^([0-9\.]+).*/\1/')
    if [ "$INSTALLED_VBOX" != "$VBOX" ]; then
        echo "Installed VBoxGuestAdditions ($INSTALLED_VBOX) do not match Virtualbox version ($VBOX)"
        install_vbox=1
    else
        echo "Installed VBoxGuestAdditions match Virtualbox version $VBOX"
    fi
else
    install_vbox=1
fi
if [ $install_vbox -eq 1 ]; then
    echo "Removing old VBoxGuestAdditions"
    apt-get -q=2 remove virtualbox-guest-utils >$LOG 2>&1 || echo
    echo "Installing VBoxGuestAdditions"
    set -e
    cd /tmp
    wget -q http://download.virtualbox.org/virtualbox/$VBOX/VBoxGuestAdditions_$VBOX.iso >$LOG 2>&1
    mount VBoxGuestAdditions_$VBOX.iso -o loop /mnt                   >$LOG 2>&1
    set +e
    sh /mnt/VBoxLinuxAdditions.run --nox11 -- --force                 >$LOG 2>&1
    umount /mnt
    rm VBoxGuestAdditions_$VBOX.iso
fi

#
# Install some requirements
#
apt-get update >$LOG 2>&1
apt-get upgrade --assume-yes
# libzip-dev - for Net::SSLeay
# libexpat1-dev - for XML::Parser
# linux-headers-amd64 - required to compile guest addons using "vagrant vbguest" (on the host)
install_packages mc rsync gettext \
  apache2 libapache2-mod-fcgid \
  libssl-dev libzip-dev libexpat1-dev \
  libtest-deep-perl libtest-exception-perl \
  linux-headers-amd64

#
# Install CPANminus
#
if ! which cpanm >/dev/null; then
    echo "Installing cpanm"
    curl -s -L https://cpanmin.us | perl - --sudo App::cpanminus >$LOG 2>&1 || _exit $?
fi

#
# Helper scripts
#
if [ $(grep -c '/vagrant/scripts' /root/.bashrc) -eq 0 ]; then
    echo "export PATH=$PATH:/vagrant/scripts"              >> /root/.bashrc
    echo "export PATH=$PATH:/vagrant/scripts"              >> /home/vagrant/.profile
    echo "/vagrant/scripts/oxi-help"                       >> /home/vagrant/.profile
fi

set +e
