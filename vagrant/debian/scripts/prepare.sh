#!/bin/bash

# This script must be run on the host machine and expects that the package
# signing key is in the local gpg key list and the gpg command is available
# It will transfer the key from the host to a in-memory directory on the
# vagrant image, so after shutting down the vm the key is gone

DIST=$1

OLDPWD=`pwd`
cd `dirname $0`

if [ ! $DIST ]; then
    # try to guess dist by looking at the running VMs
    for CAND in jessie trusty; do
        RUNS=`vagrant status build-$CAND | grep running`
        if [ ! -z "$RUNS" ]; then
            DIST=$CAND
            break ;
        fi;
    done;

    if [ -z $DIST ]; then
        echo "Unable to autodetect distro, please specify as argument";
        exit 1;
    fi;

    echo "Autodetected dist: $DIST - continue? [Y/n]";
    read PROMPT
    if [ "$PROMPT" == "n" ]; then exit; fi;

fi;

which gpg-agent || apt-get --assume-yes install gnupg-agent

if [ "$DIST" == "jessie" ]; then
    KEYID=`grep SignWith ../../../package/debian/reprepro-debian/distributions | cut -d ":" -f2`
elif [ "$DIST" == "trusty" ]; then
    KEYID=`grep SignWith ../../../package/debian/reprepro-ubuntu/distributions | cut -d ":" -f2`
else
    echo "Unknown distro $DIST - allowed values are jessie or trusty"; exit 1;
fi;

VM="build-$DIST"
gpg --armor --export-secret-key $KEYID | vagrant ssh $VM -c "/vagrant/scripts/.loadkey.sh"

echo "Now run 'vagrant ssh $VM -c /vagrant/scripts/reprepro.sh'"

cd $OLDPWD
