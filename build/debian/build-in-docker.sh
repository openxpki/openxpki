#!/bin/bash

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
        CONFDIR="--confdir /tmp/openxpki/build/debian/reprepro"
    fi
    find /packages /extra-packages -name "*.deb" | \
        xargs -L1 --no-run-if-empty reprepro $CONFDIR --basedir /repository includedeb buster;

    # Add the apt config
    echo $SOURCE > /repository/openxpki.list
    gpg --export --armor > /repository/Release.key

}

fetchgit() {

    cd /tmp

    # code repo including git repo with a checkedout branch must be mounted at /openxpki
    # we clone the currently checked out branch from the mountpoint to /tmp
    mybranch=$(git -C /openxpki rev-parse --abbrev-ref HEAD)
    git clone /openxpki --branch "$mybranch" --single-branch
    cd openxpki

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

# no target, build openxpki base module
if [ $# == 1 ] && [ "$1" == "repo" ]; then
    makerepo
else
    test -d /deps && installdeps
    test -d /tmp/openxpki/ || fetchgit
    if [ $# == 0 ]; then
        make openxpki
    # should be a list of make targets
    else
        for var in "$@"; do
            make "$var"
        done
    fi
    cp $(find deb -name "*.deb") /packages/
fi
