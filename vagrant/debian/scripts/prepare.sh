#!/bin/bash

# This script must be run on the host machine and expects that the package
# signing key is in the local gpg key list and the gpg command is available
# It will transfer the key from the host to a in-memory directory on the
# vagrant image, so after shutting down the vm the key is gone

DIST=$1
if [ "$DIST" == "jessie" ]; then
    KEYID=`grep SignWith ../../../package/debian/reprepro-debian/distributions | cut -d ":" -f2`
elif [ "$DIST" == "trusty" ]; then
    KEYID=`grep SignWith ../../../package/debian/reprepro-debian/distributions | cut -d ":" -f2`
else 
    echo "Unknown distro $DIST - allowed values are jessie or trusty"; exit 1;
fi;

VM="build-$DIST"
gpg --armor --export-secret-key $KEYID | vagrant ssh $VM -c "/vagrant/scripts/.loadkey.sh"

echo "Now run 'vagrant ssh $VM -c /vagrant/scripts/reprepro.sh'"
