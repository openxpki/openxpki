#!/bin/bash

#
# If $OXI_TEST_RUN is set, only the specified type of tests will be run.
# This is used in travis.yml to start parallel builds.
#

if [ -z "$TRAVIS_BUILD_ID" ]; then
    echo "This script only works in the Travis-CI environment (i.e. called by travis.yml)"
    exit 1
fi

#
# Check out config repository
#

# get commit id of branch "develop" in official repo
git clone --quiet --depth=1 --branch=develop https://github.com/openxpki/openxpki.git ./temp-orig-dev
pushd ./temp-orig-dev
COMMIT_ID_DEVELOP=$(git rev-parse HEAD)
popd
rm -rf ./temp-orig-dev

# use config "develop" branch if code branch is based on "develop"
echo "======================================="
if git merge-base --is-ancestor $COMMIT_ID_DEVELOP HEAD; then
    echo "Using config branch 'develop'!"
    pushd ./config
    git checkout develop
    popd
else
    echo "Using default config branch"
fi
echo "======================================="

#
# Compilation
#
cd $TRAVIS_BUILD_DIR/core/server
# disable man pages
sed -ri 's/^(WriteMakefile.*)/\1\nMAN1PODS=>{},\nMAN3PODS=>{},/' Makefile.PL
perl Makefile.PL
make

#
# Tests
#

# Unit tests + code coverage (submitted to coveralls.io)
if [ "unit_coverage" == "$OXI_TEST_RUN" -o -z "$OXI_TEST_RUN" ]; then
    figlet 'unit tests'
    ~/perl5/bin/cover -test -report coveralls
    exit $?
fi

#### make test    (already done via "cover -test")

#
# Installation
#

make install

cd $TRAVIS_BUILD_DIR

# Copy config and create directories
export TRAVIS_USER=$(whoami)
export TRAVIS_USERGROUP=$(getent group $TRAVIS_USER | cut -d: -f1)
sudo mkdir -p              /etc/openxpki
sudo cp -R ./config/* /etc/openxpki
sudo chown -R $TRAVIS_USER /etc/openxpki
sudo mkdir -p              /var/openxpki/session
sudo chown -R $TRAVIS_USER /var/openxpki
sudo mkdir -p              /var/log/openxpki
sudo chown -R $TRAVIS_USER /var/log/openxpki

# Custom configuration for TravisCI
sed -ri 's/^(user:\s+)\S+/\1'$TRAVIS_USER'/'       /etc/openxpki/config.d/system/server.yaml
sed -ri 's/^(group:\s+)\S+/\1'$TRAVIS_USERGROUP'/' /etc/openxpki/config.d/system/server.yaml
sed -ri 's/^(pid_file:\s+)\S+/\1\/var\/openxpki\/openxpkid.pid/' /etc/openxpki/config.d/system/server.yaml
./tools/testenv/mysql-oxi-config.sh

# Database re-init and sample config (CA certificates etc.)
./tools/testenv/mysql-create-db.sh
./tools/testenv/mysql-create-schema.sh
./tools/testenv/insert-certificates.sh

# Start OpenXPKI (it's in the PATH)
openxpkictl start || cat /var/log/openxpki/*

#
# QA tests
#

declare -A testmodes=(
    ["api2"]="qatest/backend/api2/"
    ["webui"]="qatest/backend/webui/"
    ["client"]="qatest/client/"
)

for mode in "${!testmodes[@]}"; do
    if [ "$mode" == "$OXI_TEST_RUN" -o -z "$OXI_TEST_RUN" ]; then
        figlet "$mode tests"
        cd $TRAVIS_BUILD_DIR/${testmodes[$mode]} && prove -q .
        exit $?
    fi
done
