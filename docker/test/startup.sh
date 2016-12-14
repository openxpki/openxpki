#!/bin/bash

BRANCH="$1"
GITHUB_USER_REPO="$2"
CLONE_DIR=/opt/openxpki

#
# MySQL
#
echo -e "\n====[ MySQL ]===="
nohup sh -c mysqld >/tmp/mysqld.log &

echo "Waiting for MySQL to initialize (max. 60 seconds)"
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
$CLONE_DIR/tools/scripts/mysql-create-db.sh
$CLONE_DIR/tools/scripts/mysql-create-user.sh

#
# Repository clone
#
set +e

# Default: remote Github repo
REPO=https://dummy:nope@github.com/$GITHUB_USER_REPO.git

# Local repo from host (if Docker volume is mounted)
mountpoint -q /repo && REPO=file:///repo

echo -e "\n====[ Git checkout: $BRANCH from $REPO ]===="
git ls-remote -h $REPO >/dev/null 2>&1
if [ $? -ne 0 ]; then
    2>&1 echo "ERROR: Git repo either does not exist or is not readable for everyone"
    exit 1
fi
set -e
git clone --depth=1 --branch=$BRANCH $REPO $CLONE_DIR

#
# Grab and install Perl module dependencies from Makefile.PL using PPI
#
echo -e "\n====[ Scanning Makefile.PL for new Perl dependencies ]===="
cpanm --quiet --notest PPI
$CLONE_DIR/tools/scripts/makefile2cpanfile.pl > $CLONE_DIR/cpanfile
cpanm --quiet --notest --installdeps $CLONE_DIR/

#
# Unit tests
#
echo -e "\n====[ Compile and test OpenXPKI ]===="
# Config::Versioned reads USER env variable
export USER=dummy

cd $CLONE_DIR/core/server
perl Makefile.PL    > /dev/null
make                > /dev/null
make test

#
# OpenXPKI installation
#
echo -e "\n====[ Install OpenXPKI ]===="
make install > /dev/null

# directory list borrowed from /package/debian/core/libopenxpki-perl.dirs
mkdir -p /var/openxpki/session
mkdir -p /var/log/openxpki

# copy config
cp -R $CLONE_DIR/config/openxpki /etc

# customize config
sed -ri 's/^((user|group):\s+)\w+/\1root/' /etc/openxpki/config.d/system/server.yaml

cat <<__DB > /etc/openxpki/config.d/system/database.yaml
main:
    debug: 0
    type: MySQL
    host: 127.0.0.1
    name: $OXI_TEST_DB_MYSQL_NAME
    user: $OXI_TEST_DB_MYSQL_USER
    passwd: $OXI_TEST_DB_MYSQL_PASSWORD
__DB

#
# Database re-init
#
$CLONE_DIR/tools/scripts/mysql-create-db.sh
$CLONE_DIR/tools/scripts/mysql-create-schema.sh

#
# Sample config (CA certificates etc.)
#
/bin/bash $CLONE_DIR/config/sampleconfig.sh

#
# Start OpenXPKI
#
/usr/local/bin/openxpkictl start

#
# QA tests
#
# (testing /api/ before /nice/ leads to errors)
cd $CLONE_DIR/qatest/backend/nice/  && prove .
cd $CLONE_DIR/qatest/backend/api/   && prove .
cd $CLONE_DIR/qatest/backend/webui/ && prove .
