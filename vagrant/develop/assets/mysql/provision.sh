#!/bin/bash
# Provision a Vagrant box (VirtualBox VM) for testing and development:
# Install MySQL client and set up database

. /vagrant/assets/functions.sh

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
echo "MySQL: downloading and starting Docker container with database"
docker rm -f mariadb >/dev/null 2>&1
docker run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root \
           --name mariadb mariadb:10.1 >$LOG 2>&1 || _exit $?

#
# Install MySQL client
#
install_packages mariadb-client libdbd-mysql-perl

#
# Database setup
#
set -e
/code-repo/tools/testenv/mysql-wait-for-db.sh
/code-repo/tools/testenv/mysql-create-db.sh
/code-repo/tools/testenv/mysql-create-user.sh
/code-repo/tools/testenv/mysql-create-schema.sh
set +e
