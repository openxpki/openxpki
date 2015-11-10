#!/bin/bash

DIST=$1

if [ "$DIST" == "ubuntu" ]; then
    wget http://packages.openxpki.org/ubuntu/openxpki.list -O /etc/apt/sources.list.d/openxpki.list
    echo "deb http://archive.ubuntu.com/ubuntu trusty multiverse" > /etc/apt/sources.list.d/multiverse.list
else 
    wget http://packages.openxpki.org/debian/openxpki.list -O /etc/apt/sources.list.d/openxpki.list
    echo "deb http://httpredir.debian.org/debian jessie non-free" > /etc/apt/sources.list.d/non-free.list
fi

aptitude update

rm -rf /etc/openxpki/

# Install mysql without password (no prompt)
DEBIAN_FRONTEND=noninteractive aptitude install --assume-yes mysql-server
aptitude install --assume-yes --allow-untrusted libdbd-mysql-perl libopenxpki-perl openxpki-i18n  libapache2-mod-fastcgi

service apache2 restart

/vagrant/setup-dummy.sh

# Need to wait until server and watchdog are up
sleep 30;

cd /qatest/backend/nice
prove . 

cd /qatest/backend/webui
prove . 

