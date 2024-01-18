#!/bin/bash
# Basic Vagrant Box setup
set -euo pipefail

SCRIPTDIR="$(dirname "$0")"
. "$SCRIPTDIR/functions.sh"

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
# Install some required system packages (also for VBoxGuestAdditions)
#
echo "Apt - update package list"
apt-get update >$LOG 2>&1

kernel=$(uname -r)
kernel_base=$(printf '%s\n' "${kernel%%-amd64}")

# libzip-dev - for Net::SSLeay
# libexpat1-dev - for XML::Parser
# linux-headers-amd64 - required to compile guest addons using "vagrant vbguest" (on the host)
install_packages mc rsync gettext \
  apache2 libapache2-mod-fcgid \
  libssl-dev libzip-dev libexpat1-dev \
  libtest-deep-perl libtest-exception-perl \
  linux-headers-${kernel} linux-headers-${kernel_base}-common \
  build-essential curl

echo "Apt - upgrade"
apt-get upgrade --assume-yes --with-new-pkgs >$LOG 2>&1
