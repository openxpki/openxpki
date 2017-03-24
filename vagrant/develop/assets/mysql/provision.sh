#!/bin/bash
# Provision a Vagrant box (VirtualBox VM) for testing and development:
# Install MySQL client and set up database

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
echo "OXI_TEST_DB_MYSQL_NAME=openxpki"     >> /etc/environment
echo "OXI_TEST_DB_MYSQL_USER=oxitest"      >> /etc/environment
echo "OXI_TEST_DB_MYSQL_PASSWORD=openxpki" >> /etc/environment
echo "OXI_TEST_DB_MYSQL_DBHOST=127.0.0.1"  >> /etc/environment
echo "OXI_TEST_DB_MYSQL_DBPORT=3306"       >> /etc/environment
echo "OXI_TEST_DB_MYSQL_DBUSER=root"       >> /etc/environment
echo "OXI_TEST_DB_MYSQL_DBPASSWORD=root"   >> /etc/environment
while read def; do export $def; done < /etc/environment

#
# Run Docker container
#
echo "MySQL: downloading and starting Docker container with database"
docker rm -f mariadb >/dev/null 2>&1
docker run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root \
           --name mariadb mariadb:10.1                    >$LOG 2>&1 || _exit $?

#
# Install MySQL client (sqlplus64)
#
installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'mariadb-client' 2>&1 | grep -ci installed)
if [ $installed -eq 0 ]; then
    echo "MySQL: installing client"
    DEBIAN_FRONTEND=noninteractive \
     apt-get -q=2 install mariadb-client libdbd-mysql-perl >$LOG 2>&1 || _exit $?
fi

#
# Database setup
#
set -e
/code-repo/tools/testenv/mysql-wait-for-db.sh
/code-repo/tools/testenv/mysql-create-db.sh
/code-repo/tools/testenv/mysql-create-user.sh
/code-repo/tools/testenv/mysql-create-schema.sh
set +e
