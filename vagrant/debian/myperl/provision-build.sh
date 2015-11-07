#!/bin/bash
#
# Provision the myperl build vagrant instance (debian jessie)
# (run as root)

aptitude update

# Install the deps
export DEBIAN_FRONTEND=noninteractive

# use squid proxy
apt-get install -y squid-deb-proxy-client

apt-get install -y \
    git-core bzip2 screen

# For rebuilding debian packages
apt-get install -y \
    devscripts build-essential:native devscripts fakeroot

# Dependencies for building perl
apt-get install -y \
    libdb-dev libgdm-dev libbz2-dev libconfig-std-perl libtemplate-perl

# Additional dependencies needed for building CPAN modules and OpenXPKI
apt-get -y install \
    openssl libssl1.0.0 libssl-dev gettext curl \
    expat libexpat-dev \
    libconfig-std-perl libyaml-perl libtemplate-perl \
    libmysqlclient-dev mysql-server


