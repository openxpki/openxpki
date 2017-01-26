#!/bin/bash
# Provision a Vagrant box (VirtualBox VM) for testing and development:
# Install OpenXPKI

#
# Exit handler
#
LOG=$(mktemp)
function _exit () {
    if [ $1 -ne 0 -a $1 -ne 333 ]; then
        echo "$0: ERROR - last command exited with code $1, output:" >&2 && cat $LOG >&2
    fi
    rm -f $LOG
    exit $1
}
trap '_exit $?' EXIT

#
# Install OpenXPKI and Apache
#
installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'libopenxpki-perl' 2>&1 | grep -ci installed)
if [ $installed -eq 0 ]; then
    set -e
    echo "Installing OpenXPKI"
    PKGHOST=packages.openxpki.org
    curl -s -L http://$PKGHOST/debian/Release.key | apt-key add -     >$LOG 2>&1
    echo "deb http://$PKGHOST/debian/ jessie release" > /etc/apt/sources.list.d/openxpki.list
    apt update                                                        >$LOG 2>&1
    DEBIAN_FRONTEND=noninteractive \
     apt-get -q=2 install libopenxpki-perl openxpki-i18n \
                          libapache2-mod-fcgid libssl-dev             >$LOG 2>&1
    set +e
fi

#
# Install CPANminus
#
if ! which cpanm >/dev/null; then
    echo "Installing cpanm"
    curl -s -L https://cpanmin.us | perl - --sudo App::cpanminus >$LOG 2>&1 || _exit $?
fi

#
# Configure OpenXPKI
#
#
echo "Configuring OpenXPKI"

if [ $(grep -c '/vagrant/scripts' /root/.bashrc) -eq 0 ]; then
    echo "export PATH=$PATH:/vagrant/scripts"              >> /root/.bashrc
    echo "export PATH=$PATH:/vagrant/scripts"              >> /home/vagrant/.profile
    echo "/vagrant/scripts/oxi-help"                       >> /home/vagrant/.profile
fi

# Read configuration written by MySQL provisioning script
while read def; do export $def; done < /etc/environment

set -e

cat <<__DB > /etc/openxpki/config.d/system/database.yaml
main:
    debug: 0
    type: MySQL
    host: $OXI_TEST_DB_MYSQL_DBHOST
    port: $OXI_TEST_DB_MYSQL_DBPORT
    name: $OXI_TEST_DB_MYSQL_NAME
    user: $OXI_TEST_DB_MYSQL_USER
    passwd: $OXI_TEST_DB_MYSQL_PASSWORD
__DB

/bin/bash /vagrant/scripts/oxi-refresh --no-restart              2>&1 | tee $LOG

rm -rf /etc/openxpki/ssl/
/code-repo/config/sampleconfig.sh                                     >$LOG 2>&1

/usr/bin/openxpkictl start                                            >$LOG 2>&1

#
# Configure Apache
#
echo "Configuring Apache"
a2enmod cgid                                                          >$LOG 2>&1
a2enmod fcgid                                                         >$LOG 2>&1
# Need to pickup new group
/etc/init.d/apache2 restart                                           >$LOG 2>&1

#
# Cleanup
#

echo "Cleaning up Docker"
# Remove orphaned volumes - whose container does not exist (anymore)
docker volume ls -qf dangling=true \
 | while read ID; do docker volume rm $ID; done                       >$LOG 2>&1
# Remove exited / dead containers and their attached volumes
docker ps --filter status=dead --filter status=exited -aq \
 | while read ID; do docker rm -v $ID; done                           >$LOG 2>&1
# Remove old images
docker images -f "dangling=true" -q \
 | while read ID; do docker rmi $ID; done                             >$LOG 2>&1

echo "Cleaning Apt cache"
apt-get -q=2 clean                                                    >$LOG 2>&1

set +e
