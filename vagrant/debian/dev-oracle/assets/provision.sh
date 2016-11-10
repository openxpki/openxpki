#!/bin/bash

set -e

# Used when bootstrapping a "develop" machine (debian only)
# Installs the latest release + initial config from the public repo 
# as starting point

echo "export OXI_TEST_DB_ORACLE_NAME=XE"           >  /etc/profile.d/openxpki-test.sh
echo "export OXI_TEST_DB_ORACLE_USER=oxitest"      >> /etc/profile.d/openxpki-test.sh
echo "export OXI_TEST_DB_ORACLE_PASSWORD=openxpki" >> /etc/profile.d/openxpki-test.sh
. /etc/profile

#
# Install Oracle
#
installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'oracle-instantclient*' 2>&1 | grep -ci installed)
if [ $installed -eq 0 ]; then
    # quiet mode -q=2 implies -y
    echo "Building and installing Oracle Client (and required packages)"
    apt-get install -q=2 fakeroot alien libaio1
    fakeroot alien -i /vagrant/assets/oracle-instantclient12.1-*.rpm
    echo "/usr/lib/oracle/12.1/client64/lib/" > /etc/ld.so.conf.d/oracle.conf
    ldconfig

    # Oracle database connection id
    sed "s/%hostname%/$HOSTNAME/g" /vagrant/assets/tnsnames.ora > /etc/tnsnames.ora

    # Set TNS_ADMIN for sqlplus64 to find tnsnames.ora, ORACLE_HOME for Perl module DBD::Oracle
    echo "export TNS_ADMIN=/etc"                             > /etc/profile.d/oracle.sh
    echo "export ORACLE_HOME=/usr/lib/oracle/12.1/client64" >> /etc/profile.d/oracle.sh
    . /etc/profile

    # DBD::Oracle searches demo.mk there
    ln -s /usr/share/oracle/12.1/client64/demo/demo.mk /usr/share/oracle/12.1/client64/
fi

echo "Waiting for database to become available (max. 60 seconds)"
set +e
sec=0; error=1
while [ $error -ne 0 -a $sec -lt 60 ]; do
    error=$(echo "quit;" | sqlplus64 -s system/oracle@XE | grep -c ORA-)
    sec=$[$sec+1]
    sleep 1
done
set -e

if [ $error -ne 0 ]; then
    echo "It seems that the Oracle database was not started. Output:"
    echo "quit;" | sqlplus64 -s system/oracle@XE
    exit 1
fi

echo "Creating OpenXPKI user and database schema"
cat /vagrant/assets/create-user.sql \
   | sed "s/%user%/$OXI_TEST_DB_ORACLE_USER/g; s/%password%/$OXI_TEST_DB_ORACLE_PASSWORD/g" \
   | sqlplus64 -s system/oracle@XE
sqlplus64 $OXI_TEST_DB_ORACLE_USER/$OXI_TEST_DB_ORACLE_PASSWORD@XE @/code-repo/config/sql/schema-oracle.sql

#
# Install CPANminus
#
if ! which cpanm >/dev/null; then
    echo "Installing cpanm"
    curl -s -L https://cpanmin.us | perl - --sudo App::cpanminus >/dev/null
fi

#
# Install DBD::Oracle
#
echo "Installing Perl modules"
cpanm --quiet DBD::Oracle DBD::SQLite

#
# Configure Apache
#
a2enmod cgid
a2enmod fcgid

#
# Install OpenXPKI
#
installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'libopenxpki-perl' 2>&1 | grep -ci installed)
if [ $installed -eq 0 ]; then
    echo "Installing OpenXPKI"
    PKGHOST=packages.openxpki.org
    curl -s -L http://$PKGHOST/debian/Release.key | apt-key add -
    echo "deb http://$PKGHOST/debian/ jessie release" > /etc/apt/sources.list.d/openxpki.list
    apt update
    apt-get install -q=2 libopenxpki-perl openxpki-i18n libapache2-mod-fcgid
fi

#
# Configure OpenXPKI
#
cat <<'__DB' > /etc/openxpki/config.d/system/database.yaml
main:
    debug: 0
    type: Oracle
    user: openxpki
    passwd: openxpki
    name: XE
__DB

/bin/bash /vagrant/assets/update-code.sh --no-restart

rm -rf /etc/openxpki/ssl/
/bin/bash /code-repo/config/sampleconfig.sh

# Need to pickup new group
/etc/init.d/apache2 restart

/usr/bin/openxpkictl start
