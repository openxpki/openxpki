#!/bin/bash

DIST=$1

if [ "$DIST" == "ubuntu" ]; then
    wget http://packages.openxpki.org/ubuntu/openxpki.list -O /etc/apt/sources.list.d/openxpki.list
else 
    wget http://packages.openxpki.org/debian/openxpki.list -O /etc/apt/sources.list.d/openxpki.list
fi

# Import the release key
wget http://packages.openxpki.org/debian/Release.key -O - | apt-key add - 

aptitude update

rm -rf /etc/openxpki/

# Install mysql without password (no prompt)
DEBIAN_FRONTEND=noninteractive aptitude install --assume-yes mysql-server
aptitude install --assume-yes libdbd-mysql-perl libopenxpki-perl openxpki-i18n  libapache2-mod-fcgid

a2enmod  cgid
a2enmod  fcgid

service apache2 restart

/vagrant/setup-dummy.sh

# Need to wait until server and watchdog are up
sleep 30;

cd /qatest/backend/nice
prove . 

cd /qatest/backend/webui
prove . 

