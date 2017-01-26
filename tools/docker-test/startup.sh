#!/bin/bash

BRANCH="$1"
GITHUB_USER_REPO="$2"
CLONE_DIR=/opt/openxpki

#
# Exit handler - run bash on errors to allow inspection of log files
#
function _exit () {
    if [ $1 -ne 0 ]; then
        echo -e "\n==========[ ERROR CODE $1 ]==========" >&2
        echo "There was an error, you can now inspect the log files under /var/log/openxpki/" >&2
        echo "and then finally stop the Docker container with 'exit'." >&2
        /bin/bash
    fi
    exit $1
}
trap '_exit $?' EXIT

#
# Repository clone
#
set +e

# Default: remote Github repo
REPO=https://dummy:nope@github.com/$GITHUB_USER_REPO.git

# Local repo from host (if Docker volume is mounted)
mountpoint -q /repo && test -z "$GITHUB_USER_REPO" && REPO=file:///repo

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
# Database setup
#
echo -e "\n====[ MySQL ]===="
nohup sh -c mysqld >/tmp/mysqld.log &
set +e
$CLONE_DIR/tools/scripts/mysql-wait-for-db.sh
set -e
$CLONE_DIR/tools/scripts/mysql-create-db.sh
$CLONE_DIR/tools/scripts/mysql-create-user.sh

#
# OpenXPKI compilation
#
echo -e "\n====[ Compile OpenXPKI ]===="
# Config::Versioned reads USER env variable
export USER=dummy

cd $CLONE_DIR/core/server
perl Makefile.PL                                        > /dev/null
make                                                    > /dev/null

#
# Unit tests
#
if [ -z "$OXI_TEST_ONLY" -o "$OXI_TEST_ONLY" == "unit" ]; then
    echo -e "\n====[ Testing part 1: unit tests ]===="
    make test
    test "$OXI_TEST_ONLY" == "unit" && exit
fi

#
# OpenXPKI installation
#
echo -e "\n====[ Install OpenXPKI ]===="
echo "Copying files"
make install                                            > /dev/null

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
    host: $OXI_TEST_DB_MYSQL_DBHOST
    port: $OXI_TEST_DB_MYSQL_DBPORT
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
echo "Creating sample config (CA certificates etc.)"
/bin/bash $CLONE_DIR/config/sampleconfig.sh             > /dev/null

#
# Start OpenXPKI
#
/usr/local/bin/openxpkictl start

#
# QA tests
#
# (testing /api/ before /nice/ leads to errors)
if [ -z "$OXI_TEST_ONLY" -o "$OXI_TEST_ONLY" == "nice" ]; then
    echo -e "\n====[ Testing part 2: QA tests ("nice") ]===="
    echo "cd $CLONE_DIR/qatest/backend/nice/ && prove -q ."
    cd $CLONE_DIR/qatest/backend/nice/  && prove -q .
    test "$OXI_TEST_ONLY" == "nice" && exit || true
fi

if [ -z "$OXI_TEST_ONLY" -o "$OXI_TEST_ONLY" == "api" ]; then
    echo -e "\n====[ Testing part 2: QA tests ("api") ]===="
    echo "cd $CLONE_DIR/qatest/backend/api/ && prove -q ."
    cd $CLONE_DIR/qatest/backend/api/   && prove -q .
    test "$OXI_TEST_ONLY" == "api" && exit || true
fi

if [ -z "$OXI_TEST_ONLY" -o "$OXI_TEST_ONLY" == "webui" ]; then
    echo -e "\n====[ Testing part 2: QA tests ("webui") ]===="
    echo "cd $CLONE_DIR/qatest/backend/webui/ && prove -q ."
    cd $CLONE_DIR/qatest/backend/webui/ && prove -q .
    test "$OXI_TEST_ONLY" == "webui" && exit || true
fi
