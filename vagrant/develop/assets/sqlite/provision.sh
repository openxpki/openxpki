#!/bin/bash
# Provision a Vagrant box (VirtualBox VM) for testing and development:
# Install SQLite client and set up database

ROOTDIR="$(dirname "$0")/.."; mountpoint -q /vagrant && ROOTDIR=/vagrant/assets
. "$ROOTDIR/functions.sh"

#
# Config
#
SQLITE_PATH=/run-env/sqlite.db
rm -f $SQLITE_PATH
touch $SQLITE_PATH
chmod 0666 $SQLITE_PATH

if ! $(grep -q OXI_TEST_DB_SQLITE_NAME /etc/environment); then
    echo "OXI_TEST_DB_SQLITE_NAME=$SQLITE_PATH" >> /etc/environment
fi
while read def; do export $def; done < /etc/environment

#
# Install SQLite client (sqlite3)
#
install_packages sqlite3 libdbd-sqlite3-perl

#
# Database setup
#
set -e
echo "SQLite: setting up database (schema)"
sqlite3 $SQLITE_PATH < $OXI_TEST_SAMPLECONFIG_DIR/contrib/sql/schema-sqlite.sql >$LOG 2>&1
set +e
