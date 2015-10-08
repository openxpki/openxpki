#!/bin/bash
#
# Provision the myperl test vagrant instance (debian jessie)
# (run as root)

set -x

if [ -x /vagrant/cache/squid-deb-proxy-client.sh ]; then
    /vagrant/cache/squid-deb-proxy-client.sh
fi

aptitude update

# Install the deps
export DEBIAN_FRONTEND=noninteractive

apt-get install -y \
    git-core bzip2 screen

# For using openxpki stuff
apt-get install -y \
    apache2 mysql-server

