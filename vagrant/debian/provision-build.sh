#!/bin/bash
#wget http://packages.openxpki.org/debian/openxpki.list -O /etc/apt/sources.list.d/openxpki.list

aptitude update

# Install the deps
export DEBIAN_FRONTEND=noninteractive
aptitude install --assume-yes  dh-make-perl mysql-server
cat /code-repo/package/debian/build-deps.lst | xargs aptitude install --assume-yes

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
wget http://search.cpan.org/CPAN/authors/id/B/BI/BINGOS/ExtUtils-MakeMaker-6.98.tar.gz 
wget http://search.cpan.org/CPAN/authors/id/L/LE/LEONT/Module-Build-0.4205.tar.gz
tar -ax --strip-components=2 -f  ExtUtils-MakeMaker-6.98.tar.gz ExtUtils-MakeMaker-6.98/lib/
tar -ax --strip-components=2 -f  Module-Build-0.4205.tar.gz Module-Build-0.4205/lib/

cd ../

# No build the deps
make clean
make cpan_dependency cpan_dependency2 
make core
make i18n

# Install the stuff
dpkg -i deb/cpan/*deb deb/core/*deb

# This pulls in the deps from the openxpki packages
apt-get  install --fix-broken --yes

# run the setup stuff
/vagrant/setup-dummy.sh

# Kick off prove
cd /code-repo/qatest/backend/nice
prove . 

cd /code-repo/qatest/backend/webui
prove . 

