#!/bin/bash

# This script must be run on the host machine and expects that the package
# signing key is in the local gpg key list and the gpg command is available
# It will transfer the key from the host to a in-memory directory on the
# vagrant image, so after shutting down the vm the key is gone

DIST=$1

OLDPWD=`pwd`
cd `dirname $0`

VM="build"
KEYID=`grep SignWith ../../../package/debian/reprepro-debian/distributions | cut -d ":" -f2`

which gpg-agent || apt-get --assume-yes install gnupg-agent
gpg --armor --export-secret-key $KEYID | vagrant ssh $VM -c "/vagrant/scripts/.loadkey.sh"

echo "Now run 'vagrant ssh $VM -c /vagrant/scripts/reprepro.sh'"

cd $OLDPWD
