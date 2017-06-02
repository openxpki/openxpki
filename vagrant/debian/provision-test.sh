#!/bin/bash

DIST=$1

# if there is a local repository tree, we use localhost for apt
if [ -d /packages.openxpki.org ]; then

    PKGHOST=127.0.0.1

    # install apache if it is not already
    if [ ! -d /etc/apache2/sites-enabled ]; then
        apt-get update
        apt-get install --assume-yes apache2
    fi

    # remove all virtual hosts and put the repo config in
    rm /etc/apache2/sites-enabled/*

    cp /vagrant/repo.conf /etc/apache2/sites-enabled/repo.conf

    service apache2 reload

else

    PKGHOST=packages.openxpki.org

fi

if [ "$DIST" == "ubuntu" ]; then
    wget http://$PKGHOST/ubuntu/Release.key -O - | apt-key add -
    echo "deb http://packages.openxpki.org/ubuntu/ dists/trusty/release/binary-amd64/" > /etc/apt/sources.list.d/openxpki.list
else
   wget http://$PKGHOST/debian/Release.key -O - | apt-key add -
   echo "deb http://$PKGHOST/debian/ jessie release" > /etc/apt/sources.list.d/openxpki.list
fi;

apt-get update

rm -rf /etc/openxpki/

# Install mysql without password (no prompt)
DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes mysql-server

if [ "$DIST" == "ubuntu" ]; then
    apt-get --assume-yes --force-yes install libcgi-perl libmodule-load-perl
fi;

apt-get install --assume-yes --force-yes libdbd-mysql-perl libopenxpki-perl openxpki-i18n libapache2-mod-fcgid

# packages required for testing only
apt-get install --assume-yes libtest-deep-perl

a2enmod cgid
a2enmod fcgid

service apache2 restart

/vagrant/setup-dummy.sh

# Need to wait until server and watchdog are up
sleep 30;

cd /qatest/backend/nice
prove .

cd /qatest/backend/webui
prove .


