#!/bin/bash
# Provision a Vagrant box (VirtualBox VM) for testing and development:
# Install SQLite client and set up database

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
# Config
#
SQLITE_PATH=$(mktemp)
chmod 0666 $SQLITE_PATH

echo "OXI_TEST_DB_SQLITE_NAME=$SQLITE_PATH" >> /etc/environment
while read def; do export $def; done < /etc/environment

#
# Install SQLite client (sqlite3)
#
installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'sqlite3' 2>&1 | grep -ci installed)
if [ $installed -eq 0 ]; then
    echo "SQLite: installing client"
    DEBIAN_FRONTEND=noninteractive \
     apt-get -q=2 install sqlite3 libdbd-sqlite3-perl     >$LOG 2>&1 || _exit $?
fi

#
# Database setup
#
set -e
echo "SQLite: setting up database (schema)"
sqlite3 $SQLITE_PATH < /code-repo/config/sql/schema-sqlite.sql        >$LOG 2>&1
set +e
