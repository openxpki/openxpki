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

# openca-tools is now only used for scep which we do not test for now
# so there is no need to install it
# We still need openca-tools and I dont want to bother with that now
# so we just assume its on the server and pull it
#wget http://packages.openxpki.org/debian/wheezy/release/binary-amd64/openca-tools_1.3.0-1_amd64.deb -O /tmp/openca-tools_1.3.0-1_amd64.deb
#dpkg -i /tmp/openca-tools_1.3.0-1_amd64.deb

# This inits the cpan module for dh-make-perl
(echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan

# Now chdir to the debian package dir
cd /code-repo/package/debian

# For stupid deps problem, unpack current MakeMaker and Module::Build in lib
mkdir -p lib/
cd lib/

if [ ! -d "ExtUtils-MakeMaker-6.98" ]; then
        test -e ExtUtils-MakeMaker-6.98.tar.gz || wget http://search.cpan.org/CPAN/authors/id/B/BI/BINGOS/ExtUtils-MakeMaker-6.98.tar.gz
    tar -ax --strip-components=2 -f  ExtUtils-MakeMaker-6.98.tar.gz ExtUtils-MakeMaker-6.98/lib/
fi

if [ ! -d "Module-Build-0.4205" ]; then
    test -e Module-Build-0.4205.tar.gz || wget http://search.cpan.org/CPAN/authors/id/L/LE/LEONT/Module-Build-0.4205.tar.gz
    tar -ax --strip-components=2 -f  Module-Build-0.4205.tar.gz Module-Build-0.4205/lib/
fi

cd ../

# Now build the deps
make clean

# on Ubuntu 14 we also need CGI and Module::Load
if [ "`grep "Ubuntu 14" /etc/issue`" ]; then
    make trusty
    # Module::* is required by the cpan deps already
    dpkg -i deb/cpan/*deb
fi

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
cd /code-repo/qatest/backend/nice
prove .

cd /code-repo/qatest/backend/webui
prove .

