#!/bin/bash
wget http://packages.openxpki.org/debian/openxpki.list -O /etc/apt/sources.list.d/openxpki.list

aptitude update

# Install mysql without password (no prompt)
DEBIAN_FRONTEND=noninteractive aptitude install --assume-yes mysql-server
aptitude -o Dpkg::Options::="--force-overwrite" install --assume-yes --allow-untrusted libdbd-mysql-perl libopenxpki-perl openxpki-i18n

/vagrant/setup-dummy.sh

cd /qatest/backend/nice
prove . 

cd /qatest/backend/webui
prove . 

