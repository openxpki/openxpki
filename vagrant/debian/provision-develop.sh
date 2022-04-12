#!/bin/bash

DIST=$1

PKGHOST=packages.openxpki.org

wget http://$PKGHOST/debian/Release.key -O - | apt-key add -
echo "deb http://$PKGHOST/v3/debian/ buster release" > /etc/apt/sources.list.d/openxpki.list

apt-get update

rm -rf /etc/openxpki/

# Install mysql without password (no prompt)
DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes mariadb-server

apt-get install --assume-yes --force-yes libdbd-mariadb-perl libapache2-mod-fcgid \
    libopenxpki-perl openxpki-i18n openxpki-cgi-session-driver \
    libcrypt-libscep-perl libscep

# packages required for testing only
apt-get install --assume-yes libtest-deep-perl libtest-exception-perl

a2enmod cgid
a2enmod fcgid

service apache2 restart

/vagrant/setup-dummy.sh

