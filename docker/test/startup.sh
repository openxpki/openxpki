#!/bin/bash

GITHUB_USER_REPO="$1"
BRANCH="$2"

echo "====[ Start MySQL ]===="
nohup sh -c mysqld >/tmp/mysqld.log &

#
# Wait for database initialization
#
echo "MySQL: waiting for DB initialize (max. 120 seconds)"
sec=0; error=1
while [ $error -ne 0 -a $sec -lt 60 ]; do
    error=$(echo "quit" | mysql -h 127.0.0.1 -uroot --connect_timeout=1 2>&1 | grep -c ERROR)
    sec=$[$sec+1]
    sleep 1
done
if [ $error -ne 0 ]; then
    echo "It seems that the MySQL database was not started. Output:"
    echo "quit" | mysql -h 127.0.0.1 -uroot --connect_timeout=1
    exit 333
fi

set -e

#
# Database setup
#
echo "MySQL: setting up database (user + schema)"

cat <<__SQL | mysql -h 127.0.0.1 -uroot
DROP database IF EXISTS $OXI_TEST_DB_MYSQL_NAME;
CREATE database $OXI_TEST_DB_MYSQL_NAME CHARSET utf8;
CREATE USER '$OXI_TEST_DB_MYSQL_USER'@'%' IDENTIFIED BY '$OXI_TEST_DB_MYSQL_PASSWORD';
GRANT ALL ON $OXI_TEST_DB_MYSQL_NAME.* TO '$OXI_TEST_DB_MYSQL_USER'@'%';
flush privileges;
__SQL


echo "====[ Git checkout: $BRANCH from $GITHUB_USER_REPO ]===="
git clone --depth=1 --branch=$BRANCH https://github.com/$GITHUB_USER_REPO.git /opt/openxpki

echo "====[ Compile and test OpenXPKI ]===="

# Config::Versioned reads USER env variable
export USER=dummy

cd /opt/openxpki/core/server
perl Makefile.PL
make test

/bin/bash
