#!/bin/bash
# Install OpenXPKI

ROOTDIR="$(dirname "$0")"; mountpoint -q /vagrant && ROOTDIR=/vagrant/assets
. "$ROOTDIR/functions.sh"

#
# Configure OpenXPKI
#
#
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
    echo "System user 'openxpki'"
    addgroup --quiet --system openxpki
    adduser  --quiet --system --no-create-home --disabled-password --ingroup openxpki openxpki
    # add apache user to openxpki group (to allow connecting the socket)
    usermod -G openxpki www-data
else
    echo "System user 'openxpki' - already set up."
fi

# pkiadm
# if ! $(grep -q pkiadm /etc/passwd); then
#     echo "System user 'pkiadm'"
#     adduser --quiet --system --disabled-password --group pkiadm
#     usermod pkiadm -G openxpki
#     # In case somebody decided to change the home base
#     HOME=`grep pkiadm /etc/passwd | cut -d":" -f6`
#     chown pkiadm:openxpki $HOME
#     chmod 750 $HOME
# else
#     echo "System user 'pkiadm' - already set up."
# fi

# Create the sudo file to restart oxi from pkiadm
if [ -d /etc/sudoers.d ]; then
    echo "pkiadm ALL=(ALL) NOPASSWD:/etc/init.d/openxpki" > /etc/sudoers.d/pkiadm
fi

echo "Create directories and log files"

# DIRECTORIES
mkdir -p /etc/openxpki

mkdir -p /var/openxpki/session
chown -R openxpki:openxpki /var/openxpki

mkdir -p /var/log/openxpki
chown openxpki:openxpki /var/log/openxpki

mkdir -p /var/www/openxpki
chown www-data:www-data /var/www/openxpki

# LOG FILES
for f in scep.log soap.log webui.log rpc.log est.log; do
    touch /var/log/openxpki/$f
    chown www-data:openxpki /var/log/openxpki/$f
    chmod 640 /var/log/openxpki/$f
done

# logrotate
if [ -e /etc/logrotate.d/ ]; then
    echo "Configure logrotate"
    cp $OXI_TEST_SAMPLECONFIG_DIR/contrib/logrotate.conf /etc/logrotate.d/openxpki
fi

# Apache configuration
if command -v apache2 >/dev/null; then
    echo "Configure Apache"

    a2enmod cgid                                                      >$LOG 2>&1
    a2enmod fcgid                                                     >$LOG 2>&1
    # (Apache will be restarted by oxi-refresh)
fi

echo "Install OpenXPKI from host sources"
$OXI_SOURCE_DIR/tools/testenv/oxi-refresh --full 2>&1 | tee $LOG | sed -u 's/^/> /g'

set +e
