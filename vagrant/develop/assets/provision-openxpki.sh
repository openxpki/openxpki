#!/bin/bash
# Install OpenXPKI
set -euo pipefail

SCRIPTDIR="$(dirname "$0")"
. "$SCRIPTDIR/functions.sh"

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


echo "Create users, directories and set up logrotate + log files"

# create main users
bash $OXI_SOURCE_DIR/package/debian/core/libopenxpki-perl.preinst install

mkdir -p /etc/openxpki
mkdir -p /var/log/openxpki-server
mkdir -p /var/log/openxpki-client
mkdir -p /var/www/openxpki

# keep for tests with legacy config
mkdir -p /var/log/openxpki

# logrotate
if [ -e /etc/logrotate.d/ ]; then
    echo "Configure logrotate"
    cp $OXI_TEST_SAMPLECONFIG_DIR/contrib/logrotate.conf /etc/logrotate.d/openxpki
fi

# run dir
mkdir -p /run/openxpkid
chown -R openxpki:openxpki /run/openxpkid

mkdir -p /run/openxpki-terminal
chown -R openxpki:openxpki /run/openxpki-terminal

mkdir -p /run/openxpki-clientd
chown -R openxpkiclient:openxpkiclient /run/openxpki-clientd

# file based session
mkdir -p /var/openxpki/session
chown -R openxpki:openxpki /var/openxpki

# webserver dir
mkdir -p /var/www/openxpki
chown www-data:www-data /var/www/openxpki

# prevent libopenxpki-perl.postinst from complaining if run again
test -L /var/openxpki/openxpki.socket && rm /var/openxpki/openxpki.socket

# prevent libopenxpki-perl.postinst errors
echo "" > /var/www/openxpki/localconfig.yaml
echo "" > /var/www/openxpki/default.html

# set directory permissions and create pkiadm user
bash $OXI_SOURCE_DIR/package/debian/core/libopenxpki-perl.postinst configure

# client log files
for f in webui acme certep cmc est rpc scep soap; do
    touch /var/log/openxpki-client/${f}.log
    chown openxpkiclient:pkiadm /var/log/openxpki-client/${f}.log
    chmod 660 /var/log/openxpki-client/${f}.log
done

# Apache configuration
if command -v apache2 >/dev/null; then
    echo "Configure Apache"

    a2enmod ssl cgid fcgid headers rewrite proxy proxy_http macro               >$LOG 2>&1
    # (Apache will be restarted by oxi-refresh)
fi

echo "Install OpenXPKI from host sources"
$OXI_SOURCE_DIR/tools/testenv/oxi-refresh --full 2>&1 | tee $LOG | sed -u 's/^/    /mg'

set +e

#
# Helper scripts
#
tools_dir="$OXI_SOURCE_DIR/tools/testenv"
if ! grep -q "$tools_dir" /root/.bashrc; then
    echo "Set \$PATH and run 'oxi-help' on login"
    echo "export PATH=\$PATH:$tools_dir" >> /root/.bashrc
    if [[ -d /home/vagrant ]]; then
        echo "export PATH=\$PATH:$tools_dir" >> /home/vagrant/.profile
        echo "$tools_dir/oxi-help"           >> /home/vagrant/.profile
    fi
fi
