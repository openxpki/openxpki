#!/bin/bash

if [ -n "$OPENXPKI_BUILD_DEBUG" ]; then
    set -x
fi
set -e

if [ ! -e "/openxpki/.git" ]; then
    echo "Please mount a full checkout including the .git directory to /openxpki";
    exit 1;
fi

makerepo() {

    if [ -z "$SOURCE" ]; then
        SOURCE="deb http://packages.openxpki.org/v3/debian/ buster release"
    fi

    if [ -e "/signkey" ]; then
        gpg --import --batch /signkey
    else
        echo "No signing key was found - skipping signature"
    fi

    CONFDIR=""
    if [ ! -d "/repository/conf" ]; then
        CONFDIR="--confdir /openxpki/build/debian/reprepro"
    fi
    find /packages /extra-packages -name "*.deb" | \
        xargs -L1 --no-run-if-empty reprepro $CONFDIR --basedir /repository includedeb buster;

    # Add the apt config
    echo $SOURCE > /repository/openxpki.list
    gpg --export --armor > /repository/Release.key

}

fetchgit() {

    cd /tmp

    git config --global --add safe.directory /openxpki
    # code repo including git repo with a checkedout branch must be mounted at /openxpki
    # we clone the currently checked out branch from the mountpoint to /tmp
    mybranch=$(git -C /openxpki rev-parse --abbrev-ref HEAD)
    git clone /openxpki --branch "$mybranch" --single-branch

    cd openxpki

    if [ $OPENXPKI_BUILD_TAG ]; then
        git checkout $OPENXPKI_BUILD_TAG
    fi

    git submodule init
    git submodule update --checkout
    HEAD=`git -C config rev-parse HEAD | cut -c1-6`
    sed -i -r "s/^commit:.*/commit: $HEAD/" config/config.d/system/version.yaml

    # Now chdir to the debian package dir
    cd package/debian

}

installdeps() {
    find /deps -name "*.deb" | \
        xargs -L1 --no-run-if-empty dpkg --force-depends -i
    apt-get  install --fix-broken --yes
}

runtest() {

    export OPENXPKI_TEST_PASSWORD=openxpki
    cd /tmp
    rm -rf /etc/openxpki/
    dpkg --force-depends -i /packages/*.deb
    apt-get  install --fix-broken --yes

    /etc/init.d/mysql start
    echo "
    DROP database if exists openxpki;
    CREATE database openxpki CHARSET utf8;
    CREATE USER 'openxpki'@'localhost' IDENTIFIED BY 'openxpki';
    CREATE USER 'openxpki_session'@'localhost' IDENTIFIED BY 'mysecret';
    GRANT ALL ON openxpki.* TO 'openxpki'@'localhost';
    flush privileges;" | mysql -u root

    zcat "/usr/share/doc/libopenxpki-perl/examples/schema-mariadb.sql.gz" | mysql -u root openxpki

    /usr/bin/openxpkictl start

    openssl req -batch -x509 -newkey rsa:2048 -days 300 -nodes -keyout vault.key -out vault.crt -subj "/CN=Vault"
    openssl req -batch -x509 -newkey rsa:2048 -days 1050 -nodes -keyout signer.key -out signer.crt -subj "/CN=Test CA Signer"
    mkdir -p /etc/openxpki/local/keys/
    openxpkiadm alias --file vault.crt --key vault.key --realm democa --token datasafe
    openxpkiadm alias --file signer.crt --key signer.key --realm democa --token certsign

    cd /tmp/openxpki/qatest/backend/webui

    prove .
}

# no target, build openxpki base module
if [ $# == 1 ] && [ "$1" == "repo" ]; then
    makerepo
else
    test -d /deps && installdeps
    test -d /tmp/openxpki/ || fetchgit
    if [ $# == 1 ] && [ "$1" == "test" ]; then
        runtest
        exit 0
    elif [ $# == 0 ]; then
        make openxpki
    # should be a list of make targets
    else
        for var in "$@"; do
            make "$var"
        done
    fi
    cp $(find deb -name "*.deb") /packages/
fi
