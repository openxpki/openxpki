#!/bin/bash
# Provision a Vagrant box (VirtualBox VM) for testing and development:
# Install OpenXPKI

#
# Install OpenXPKI and Apache
#
installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'libopenxpki-perl' 2>&1 | grep -ci installed)
if [ $installed -eq 0 ]; then
    set -e
    echo "Installing OpenXPKI"
    PKGHOST=packages.openxpki.org
    curl -s -L http://$PKGHOST/debian/Release.key | apt-key add -
    echo "deb http://$PKGHOST/debian/ jessie release" > /etc/apt/sources.list.d/openxpki.list
    apt update
    apt-get -q=2 install libopenxpki-perl openxpki-i18n libapache2-mod-fcgid
    set +e
fi

#
# Install CPANminus
#
if ! which cpanm; then
    echo "Installing cpanm"
    curl -s -L https://cpanmin.us | perl - --sudo App::cpanminus >/dev/null || exit 1
fi

#
# Configure OpenXPKI
#
#
set -e

echo "Configuring OpenXPKI"
cat <<__DB > /etc/openxpki/config.d/system/database.yaml
main:
    debug: 0
    type: MySQL
    host: 127.0.0.1
    name: $OXI_TEST_DB_MYSQL_NAME
    user: $OXI_TEST_DB_MYSQL_USER
    passwd: $OXI_TEST_DB_MYSQL_PASSWORD
__DB

/bin/bash /vagrant/assets/update-code.sh --no-restart

rm -rf /etc/openxpki/ssl/
/bin/bash /code-repo/config/sampleconfig.sh

/usr/bin/openxpkictl start
set +e

#
# Configure Apache
#
echo "Configuring Apache"
a2enmod cgid
a2enmod fcgid
# Need to pickup new group
/etc/init.d/apache2 restart

#
# Cleanup
#

echo "Cleaning up Docker"
# Remove orphaned volumes - whose container does not exist (anymore)
docker volume ls -qf dangling=true | while read ID; do docker volume rm $ID; done
# Remove exited / dead containers and their attached volumes
docker ps --filter status=dead --filter status=exited -aq | while read ID; do docker rm -v $ID; done
# Remove old images
docker images -f "dangling=true" -q | while read ID; do docker rmi $ID; done

echo "Cleaning up Apt cache"
apt-get -q=2 clean
