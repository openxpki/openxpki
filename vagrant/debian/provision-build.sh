#!/bin/bash
#wget http://packages.openxpki.org/debian/openxpki.list -O /etc/apt/sources.list.d/openxpki.list
set -e
set -x

DEBIAN_CODENAME=`lsb_release -sc`

apt-get update

# Install the deps
export DEBIAN_FRONTEND=noninteractive
apt-get install --assume-yes  dh-make-perl libapache2-mod-fcgid



# Debian Buster has renamed the mysql server package
case $DEBIAN_CODENAME in
    jessie)
	PACKAGES="mysql-server"
	;;
    stretch|buster)
	PACKAGES="default-mysql-server"
	;;
    *)
	echo "Unsupported Debian release $DEBIAN_CODENAME"
	exit 1
	;;
esac

apt-get install --assume-yes $PACKAGES libdbd-mysql-perl

if [ -e /code-repo/package/debian/build-deps-$DEBIAN_CODENAME.lst ]; then
    cat /code-repo/package/debian/build-deps-$DEBIAN_CODENAME.lst \
        | xargs apt-get install --assume-yes
else
    cat /code-repo/package/debian/build-deps.lst \
        | xargs apt-get install --assume-yes
fi

# packages required for testing only
apt-get install --assume-yes libtest-deep-perl

# make sure libcryptx-perl is found by dh-make-perl and package versions are found
apt-file update
apt-cache dumpavail | dpkg --merge-avail

# This inits the cpan module for dh-make-perl
(echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan

# Now chdir to the debian package dir
cd /code-repo/package/debian

# Now build the deps
make clean

make cpan_dependency cpan_dependency2

# Install remaining deps
dpkg -i deb/cpan/*deb

make openxpki

# Install the stuff - this exits with false due to unresolved deps
dpkg -i deb/core/*deb || /bin/true

# This pulls in the deps from the openxpki packages
apt-get  install --fix-broken --yes

# run the setup stuff
/vagrant/setup-dummy.sh

# Need to wait until server and watchdog are up
sleep 30;

# Kick off prove
#cd /code-repo/qatest/backend/nice
#prove .

cd /code-repo/qatest/backend/webui
prove .

