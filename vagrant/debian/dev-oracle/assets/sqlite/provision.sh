#!/bin/bash
# Provision a Vagrant box (VirtualBox VM) for testing and development:
# Install MySQL client and set up database

SQLITE_PATH=$(mktemp)
chmod 0666 $SQLITE_PATH

echo "export OXI_TEST_DB_SQLITE_NAME=$SQLITE_PATH" >  /etc/profile.d/openxpki-test-sqlite.sh
. /etc/profile

#
# Install SQLite client (sqlite3)
#
installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'sqlite3' 2>&1 | grep -ci installed)
if [ $installed -eq 0 ]; then
    echo "SQLite: installing client"
    DEBIAN_FRONTEND=noninteractive apt-get -q=2 install sqlite3 libdbd-sqlite3-perl
    test $? -ne 0 && exit $?
fi

#
# Database setup
#
set -e
echo "SQLite: setting up database"
sqlite3 $SQLITE_PATH < /code-repo/config/sql/schema-sqlite.sql >/dev/null
set +e
