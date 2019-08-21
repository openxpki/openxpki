#!/bin/bash
# Install OpenXPKI

. /vagrant/assets/functions.sh

#
# Configure OpenXPKI
#
#
echo "Configuring OpenXPKI"

set -e

# ENVIRONMENT

if ! $(grep -q OXI_CORE_DIR /etc/environment); then
    OXI_CORE_DIR=/run-env/openxpki
    mkdir -p $OXI_CORE_DIR
    echo "OXI_CORE_DIR=$OXI_CORE_DIR" >> /etc/environment
fi

# Read our configuration and the one written by previous (DB) provisioning scripts
while read def; do export $def; done < /etc/environment

# STARTUP SCRIPT
## Disabled because it expects mysql package and is not needed in dev env (?)
## cp /code-repo/package/debian/core/libopenxpki-perl.openxpkid.init /etc/init.d/openxpkid

# USERS AND GROUPS

# openxpki
if ! $(grep -q openxpki /etc/passwd); then
    addgroup --quiet --system openxpki
    adduser  --quiet --system --no-create-home --disabled-password --ingroup openxpki openxpki
fi

# add apache user to openxpki group (to allow connecting the socket)
usermod -G openxpki www-data

# pkiadm
if ! $(grep -q pkiadm /etc/passwd); then
    adduser --quiet --system --disabled-password --group pkiadm
    usermod pkiadm -G openxpki
    # In case somebody decided to change the home base
    HOME=`grep pkiadm /etc/passwd | cut -d":" -f6`
    chown pkiadm:openxpki $HOME
    chmod 750 $HOME
fi

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
    cp $OXI_TEST_SAMPLECONFIG_DIR/contrib/logrotate.conf /etc/logrotate.d/openxpki
fi

# CONFIGURATION and DATABASE SETUP
/bin/bash /vagrant/scripts/oxi-refresh --full                    2>&1 | tee $LOG

#
# Apache configuration
#
if [ -e /etc/init.d/apache2 ]; then
    echo "Configuring Apache"
    # Ubuntu/Jessie
    if [ -d /etc/apache2/conf-available ]; then
        cp $OXI_TEST_SAMPLECONFIG_DIR/contrib/apache2-openxpki.conf /etc/apache2/conf-available/openxpki.conf
        /usr/sbin/a2enconf openxpki
    fi
    # Wheezy etc.
    if [ -d /etc/apache2/conf.d ]; then
        cp $OXI_TEST_SAMPLECONFIG_DIR/contrib/apache2-openxpki.conf /etc/apache2/conf.d/openxpki.conf
    fi

    a2enmod cgid                                                      >$LOG 2>&1
    a2enmod fcgid                                                     >$LOG 2>&1
    # Needed to pickup new group
    /etc/init.d/apache2 restart                                       >$LOG 2>&1

    # Specify hostname to force MySQL connection via TCP, not socket
    echo "Configuration OpenXPKI WebUI"
    sed -ri 's/^(#\s*)?(DataSource\s*=).*/\2 dbi:mysql:dbname=openxpki;host=127.0.0.1/' /etc/openxpki/webui/default.conf
    sed -ri 's/^(#\s*)?(User\s*=).*/\2 openxpki_session/' /etc/openxpki/webui/default.conf
    sed -ri 's/^(#\s*)?(Password\s*=).*/\2 mysecret/' /etc/openxpki/webui/default.conf
fi

set +e
