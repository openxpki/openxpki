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
# Install package dependencies
#
installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'libapache2-mod-fcgid' 2>&1 | grep -ci installed)
if [ $installed -eq 0 ]; then
    set -e
    echo "Installing OpenXPKI package dependencies"
    apt update                                                        >$LOG 2>&1
    DEBIAN_FRONTEND=noninteractive \
     apt-get -q=2 install apache2 libapache2-mod-fcgid libssl-dev     >$LOG 2>&1
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

set -e

# ENVIRONMENT

if [ $(grep -c '/vagrant/scripts' /root/.bashrc) -eq 0 ]; then
    echo "export PATH=$PATH:/vagrant/scripts"              >> /root/.bashrc
    echo "export PATH=$PATH:/vagrant/scripts"              >> /home/vagrant/.profile
    echo "/vagrant/scripts/oxi-help"                       >> /home/vagrant/.profile
fi
OXI_CORE_DIR=$(mktemp -d)
echo "OXI_CORE_DIR=$OXI_CORE_DIR" >> /etc/environment

# Read our configuration and the one written by MySQL provisioning script
while read def; do export $def; done < /etc/environment

# STARTUP SCRIPT
## Disables because it expects mysql package and is not needed in dev env (?)
## cp /code-repo/package/debian/core/libopenxpki-perl.openxpkid.init /etc/init.d/openxpkid

# USERS AND GROUPS

# openxpki
addgroup --quiet --system openxpki
adduser  --quiet --system --no-create-home --disabled-password --ingroup openxpki openxpki

# add apache user to openxpki group (to allow connecting the socket)
usermod -G openxpki www-data

# pkiadm
adduser --quiet --system --disabled-password --group pkiadm
usermod pkiadm -G openxpki
# In case somebody decided to change the home base
HOME=`grep pkiadm /etc/passwd | cut -d":" -f6`
chown pkiadm:openxpki $HOME
chmod 750 $HOME

# Create the sudo file to restart oxi from pkiadm
if [ -d /etc/sudoers.d ]; then
    echo "pkiadm ALL=(ALL) NOPASSWD:/etc/init.d/openxpki" > /etc/sudoers.d/pkiadm
fi

# DIRECTORIES

mkdir -p /etc/openxpki

mkdir -p /var/openxpki/session
chown -R openxpki:openxpki /var/openxpki

mkdir -p /var/log/openxpki
chown openxpki:openxpki /var/log/openxpki

mkdir -p /var/www/openxpki
chown www-data:www-data /var/www/openxpki

# LOG FILES

for f in scep.log soap.log webui.log rpc.log; do
    touch /var/log/openxpki/$f
    chown www-data:openxpki /var/log/openxpki/$f
    chmod 640 /var/log/openxpki/$f
done

# logrotate
if [ -e /etc/logrotate.d/ ]; then
    cp /code-repo/config/logrotate.conf /etc/logrotate.d/openxpki
fi

# CONFIGURATION

rsync -a /code-repo/config/openxpki/* /etc/openxpki/                  >$LOG 2>&1
chmod 750              /etc/openxpki/config.d
chmod 750              /etc/openxpki/ssl/
chown -R openxpki:root /etc/openxpki/config.d
chown -R openxpki:root /etc/openxpki/ssl/

# DATABASE SETUP

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

openxpkictl start                                                     >$LOG 2>&1

#
# Apache configuration
#
if [ -e /etc/init.d/apache2 ]; then
    echo "Configuring Apache"
    # Ubuntu/Jessie
    if [ -d /etc/apache2/conf-available ]; then
        cp /code-repo/config/apache/openxpki.conf /etc/apache2/conf-available/
        /usr/sbin/a2enconf openxpki
    fi
    # Wheezy etc.
    if [ -d /etc/apache2/conf.d ]; then
        cp /code-repo/config/apache/openxpki.conf /etc/apache2/conf.d/
    fi

    a2enmod cgid                                                      >$LOG 2>&1
    a2enmod fcgid                                                     >$LOG 2>&1
    # Need to pickup new group
    /etc/init.d/apache2 restart                                       >$LOG 2>&1
fi

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
