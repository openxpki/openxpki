#!/bin/bash

# Used when bootstrapping a "develop" machine (debian only)
# Installs the latest release + initial config from the public repo 
# as starting point

PKGHOST=packages.openxpki.org
wget http://$PKGHOST/debian/Release.key -O - | apt-key add -
echo "deb http://$PKGHOST/debian/ jessie release" > /etc/apt/sources.list.d/openxpki.list

aptitude update

rm -rf /etc/openxpki/

# Install mysql without password (no prompt)
DEBIAN_FRONTEND=noninteractive aptitude install --assume-yes mysql-server
aptitude install --assume-yes libdbd-mysql-perl libopenxpki-perl openxpki-i18n libapache2-mod-fcgid

a2enmod cgid
a2enmod fcgid

service apache2 restart

/vagrant/setup-dummy.sh


