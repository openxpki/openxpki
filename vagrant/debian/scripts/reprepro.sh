#!/bin/bash

# Run this from inside your vagrant machine from a full shell
# as it will prompt you for the signing key password!

if [ ! -d /packages.openxpki.org ]; then
    echo "You must map the repository target to /packages.openxpki.org"
    exit;
fi;

DIST=`lsb_release -c -s`
if [ "$DIST" == "jessie" ]; then
    PACKAGE=debian
elif [ "$DIST" == "trusty" ]; then
    PACKAGE=ubuntu
else
    echo "Unknown distro $DIST"; exit 1;
fi;

if [ ! -e "/packages.openxpki.org/$PACKAGE/conf" ]; then
    mkdir -p /packages.openxpki.org/$PACKAGE/
    ln -s /code-repo/package/debian/reprepro-$PACKAGE /packages.openxpki.org/$PACKAGE/conf
fi;

# Install reprepro if not present
test -e /usr/bin/reprepro || sudo aptitude -y install reprepro

# Start and source gpg-agent
gpg-agent --daemon > ~/.gnupg/.agent
. ~/.gnupg/.agent

# Call reprepro
find /code-repo/package/debian/deb -maxdepth 2  -name "*.deb" | xargs reprepro --confdir /packages.openxpki.org/$PACKAGE/conf/ includedeb $DIST

# Copy the release key it does not exist
test -e /packages.openxpki.org/$PACKAGE/Release.key || cp /code-repo/package/debian/Release.key /packages.openxpki.org/$PACKAGE/

