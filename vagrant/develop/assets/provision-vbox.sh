#!/bin/bash
# Install Virtualbox guest addins
set -euo pipefail

SCRIPTDIR="$(dirname "$0")"
. "$SCRIPTDIR/functions.sh"

VBOX_VERSION="$1"

# Read our configuration and the one written by previous (DB) provisioning scripts
while read def; do export $def; done < /etc/environment

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
            echo "VBoxGuestAdditions - install libx11-6"
            install_packages libx11-6
            echo "VBoxGuestAdditions - remove old version"
            apt-get -q=2 remove virtualbox-guest-utils >$LOG 2>&1 || echo
            echo "VBoxGuestAdditions - install new version ${VBOX_VERSION}"
            cd /tmp
            wget -q http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso >$LOG 2>&1
            mount VBoxGuestAdditions_${VBOX_VERSION}.iso -o loop /mnt >$LOG 2>&1
            sh /mnt/VBoxLinuxAdditions.run --nox11 -- --force >$LOG 2>&1
            umount /mnt
            rm VBoxGuestAdditions_${VBOX_VERSION}.iso
        fi
    fi
fi
