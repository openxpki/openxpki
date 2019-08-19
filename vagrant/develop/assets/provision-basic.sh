#!/bin/bash
# Basic Vagrant Box setup

#
# Exit handler
#
LOG=$(mktemp)
function _exit () {
    if [ $1 -ne 0 -a $1 -ne 333 ]; then
        echo "$0: ERROR - last command exited with code $1, output:" >&2 && cat $LOG >&2
    fi
    rm -f $LOG
    exit $1
}
trap '_exit $?' EXIT

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
    echo "Installing VBoxGuestAdditions $VBOX"
    apt-get -q=2 -y remove virtualbox-guest-utils || echo             >$LOG 2>&1
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
set -e
echo "Installing rsync"
apt-get update                                                        >$LOG 2>&1
DEBIAN_FRONTEND=noninteractive \
 apt-get -q=2 install rsync                                           >$LOG 2>&1
set +e

#
# Install package dependencies
#
installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'libapache2-mod-fcgid' 2>&1 | grep -ci installed)
if [ $installed -eq 0 ]; then
    set -e
    echo "Installing OpenXPKI package dependencies"
    DEBIAN_FRONTEND=noninteractive \
     apt-get -q=2 install apache2 libapache2-mod-fcgid libssl-dev     >$LOG 2>&1
    set +e
fi

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
