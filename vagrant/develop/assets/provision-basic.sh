#!/bin/bash
set -euo pipefail

# Basic Vagrant Box setup

SCRIPTDIR="$(dirname "$0")"
. "$SCRIPTDIR/functions.sh"

VBOX_VERSION="$1"

#
# Environment
#
touch /etc/environment

$(grep -q OXI_SOURCE_DIR /etc/environment) || echo "OXI_SOURCE_DIR=/code-repo" >> /etc/environment
$(grep -q OXI_EE_SOURCE_DIR /etc/environment) || echo "OXI_EE_SOURCE_DIR=/code-repo/myperl-openxpki-ee" >> /etc/environment
$(grep -q OXI_TEST_SAMPLECONFIG_DIR /etc/environment) || echo "OXI_TEST_SAMPLECONFIG_DIR=/code-repo/config" >> /etc/environment

# Read our configuration and the one written by previous (DB) provisioning scripts
while read def; do export $def; done < /etc/environment

#
# Install some requirements (also for VBoxGuestAdditions)
#
echo "Apt - update package list"
apt-get update >$LOG 2>&1

# libzip-dev - for Net::SSLeay
# libexpat1-dev - for XML::Parser
# linux-headers-amd64 - required to compile guest addons using "vagrant vbguest" (on the host)
install_packages mc rsync gettext \
  apache2 libapache2-mod-fcgid \
  libssl-dev libzip-dev libexpat1-dev \
  libtest-deep-perl libtest-exception-perl \
  linux-headers-amd64 \
  build-essential curl

echo "Apt - upgrade"
apt-get upgrade --assume-yes --with-new-pkgs >$LOG 2>&1

#
# Install Virtualbox guest addins
#
if command -v dmidecode >/dev/null; then
    if [[ "$(dmidecode -s bios-version)" == "VirtualBox" ]]; then
        install_vbox=0
        if command -v VBoxService >/dev/null; then
            INSTALLED_VBOX=$(VBoxService --version | sed -r 's/^([0-9\.]+).*/\1/')
            if [ "$INSTALLED_VBOX" != "${VBOX_VERSION}" ]; then
                echo "VBoxGuestAdditions v${INSTALLED_VBOX} != Virtualbox v${VBOX_VERSION}"
                install_vbox=1
            else
                echo "VBoxGuestAdditions == Virtualbox == v${VBOX_VERSION}"
            fi
        else
            install_vbox=1
        fi
        if [ $install_vbox -eq 1 ]; then
            install_packages libx11-6
            echo "VBoxGuestAdditions - remove old version"
            apt-get -q=2 remove virtualbox-guest-utils >$LOG 2>&1 || echo
            echo "VBoxGuestAdditions - install new version ${VBOX_VERSION}"
            cd /tmp
            wget -q http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso >$LOG 2>&1
            mount VBoxGuestAdditions_${VBOX_VERSION}.iso -o loop /mnt                   >$LOG 2>&1
            sh /mnt/VBoxLinuxAdditions.run --nox11 -- --force                 >$LOG 2>&1
            umount /mnt
            rm VBoxGuestAdditions_${VBOX_VERSION}.iso
        fi
    fi
fi

#
# Install Git
#
if ! command -v git >/dev/null; then
    echo "Git"
    apt-get install -q=2 -t $(lsb_release -sc)-backports git >$LOG 2>&1
else
    echo "Git - already installed."
fi

#
# Install CPANminus
#
if ! command -v cpanm >/dev/null; then
    echo "cpanm"
    curl -s -L https://cpanmin.us | perl - --sudo App::cpanminus >$LOG 2>&1 || _exit $?
else
    echo "cpanm is already installed."
fi

#
# Helper scripts
#
tools_dir="$OXI_SOURCE_DIR/tools/testenv"
if ! grep -q "$tools_dir" /root/.bashrc; then
    echo "Set \$PATH and run 'oxi-help' on login"
    echo "export PATH=\$PATH:$tools_dir" >> /root/.bashrc
    if [[ -d /home/vagrant ]]; then
        echo "export PATH=\$PATH:$tools_dir" >> /home/vagrant/.profile
        echo "$tools_dir/oxi-help"           >> /home/vagrant/.profile
    fi
fi
