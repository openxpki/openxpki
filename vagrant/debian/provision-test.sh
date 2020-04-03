#!/bin/bash

DIST=$1

export DEBIAN_FRONTEND=noninteractive

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
apt-get install --assume-yes default-mysql-server \
    libdbd-mysql-perl libapache2-mod-fcgid \
    libcrypt-libscep-perl libscep

if [ -e "/packages/cpan" ]; then
    dpkg -i /packages/cpan/*.deb
fi

if [ -e "/packages/core" ]; then
    dpkg -i /packages/core/*.deb
    apt --assume-yes --fix-broken install
else
    apt install --assume-yes --force-yes \
        libopenxpki-perl openxpki-i18n openxpki-cgi-session-driver
fi

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


