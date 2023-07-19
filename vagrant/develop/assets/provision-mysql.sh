#!/bin/bash
# Install MySQL client and set up database
set -euo pipefail

SCRIPTDIR="$(dirname "$0")"
. "$SCRIPTDIR/functions.sh"

#
# Config
#
if ! $(grep -q OXI_TEST_DB_MYSQL_NAME /etc/environment); then
    echo "OXI_TEST_DB_MYSQL_NAME=openxpki"     >> /etc/environment
    echo "OXI_TEST_DB_MYSQL_USER=oxitest"      >> /etc/environment
    echo "OXI_TEST_DB_MYSQL_PASSWORD=openxpki" >> /etc/environment
    echo "OXI_TEST_DB_MYSQL_DBHOST=127.0.0.1"  >> /etc/environment
    echo "OXI_TEST_DB_MYSQL_DBPORT=3306"       >> /etc/environment
    echo "OXI_TEST_DB_MYSQL_DBUSER=root"       >> /etc/environment
    echo "OXI_TEST_DB_MYSQL_DBPASSWORD=root"   >> /etc/environment
fi
while read def; do export $def; done < /etc/environment

#
# Run Docker container
#
docker rm -f mariadb >/dev/null 2>&1
docker run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root \
           --name mariadb mariadb:10.5 >$LOG 2>&1 || _exit $?

#
# Install MySQL client
#
install_packages mariadb-client libmariadb-dev libdbd-mysql-perl

# Install newest DBD::MariaDB from CPAN.
# Default Debian 10 package libdbd-mariadb-perl is version 1.11 which has a bug:
#   DBD::MariaDB disconnect_all: 1 database handlers were not released (possible bug in driver) at .../DBI.pm line 759.
#   DBD::MariaDB disconnect_all: Client library was not properly deinitialized (possible bug in driver) at .../DBI.pm line 759.
cpanm DBD::MariaDB

#
# Database setup
#
set -e
$OXI_SOURCE_DIR/tools/testenv/mysql-wait-for-db.sh
$OXI_SOURCE_DIR/tools/testenv/mysql-create-db.sh
$OXI_SOURCE_DIR/tools/testenv/mysql-create-user.sh
$OXI_SOURCE_DIR/tools/testenv/mysql-create-schema.sh
set +e
