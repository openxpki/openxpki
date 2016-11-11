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
cat /etc/environment | while read def; do export $def; done

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
# Wait for database initialization
#
echo "MySQL: waiting for DB in Docker container to initialize (max. 120 seconds)"
sec=0; error=1
while [ $error -ne 0 -a $sec -lt 60 ]; do
    error=$(echo "quit" | mysql -h 127.0.0.1 -uroot -proot --connect_timeout=1 2>&1 | grep -c ERROR)
    sec=$[$sec+1]
    sleep 1
done
if [ $error -ne 0 ]; then
    echo "It seems that the MySQL database was not started. Output:"
    echo "quit" | mysql -h 127.0.0.1 -uroot -proot --connect_timeout=1
    _exit 333
fi

#
# Database setup
#
set -e
echo "MySQL: setting up database (user + schema)"

cat <<__SQL | mysql -h 127.0.0.1 -uroot -proot                        >$LOG 2>&1
DROP database IF EXISTS $OXI_TEST_DB_MYSQL_NAME;
CREATE database $OXI_TEST_DB_MYSQL_NAME CHARSET utf8;
CREATE USER '$OXI_TEST_DB_MYSQL_USER'@'%' IDENTIFIED BY '$OXI_TEST_DB_MYSQL_PASSWORD';
GRANT ALL ON $OXI_TEST_DB_MYSQL_NAME.* TO '$OXI_TEST_DB_MYSQL_USER'@'%';
flush privileges;
__SQL

mysql -h 127.0.0.1 \
      -u$OXI_TEST_DB_MYSQL_USER \
      -p$OXI_TEST_DB_MYSQL_PASSWORD \
      $OXI_TEST_DB_MYSQL_NAME \
      < /code-repo/config/sql/schema-mysql.sql                        >$LOG 2>&1
set +e
