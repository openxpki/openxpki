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

wget http://$PKGHOST/debian/Release.key -O - | apt-key add -
echo "deb http://$PKGHOST/v3/debian/ buster release" > /etc/apt/sources.list.d/openxpki.list

apt-get update

rm -rf /etc/openxpki/

# Install mysql without password (no prompt)
DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes default-mysql-server

apt-get install --assume-yes --force-yes libdbd-mysql-perl libapache2-mod-fcgid \
    libopenxpki-perl openxpki-i18n openxpki-cgi-session-driver \
    libcrypt-libscep-perl libscep

# packages required for testing only
apt-get install --assume-yes libtest-deep-perl libtest-exception-perl

a2enmod cgid
a2enmod fcgid

service apache2 restart

/vagrant/setup-dummy.sh

# Need to wait until server and watchdog are up
sleep 30;

#cd /qatest/backend/nice
#prove .

cd /qatest/backend/webui
prove .


