#!/bin/bash
set -euo pipefail
# Install SQLite client and set up database

SCRIPTDIR="$(dirname "$0")"
. "$SCRIPTDIR/functions.sh"

# Read config written by previous provisioning scripts
while read def; do export $def; done < /etc/environment

#
# Config
#
SQLITE_PATH=$OXI_CORE_DIR/sqlite.db
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
