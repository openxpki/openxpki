#!/bin/bash
wget http://packages.openxpki.org/debian/openxpki.list -O /etc/apt/sources.list.d/openxpki.list

aptitude update

# Install mysql without password (no prompt)
DEBIAN_FRONTEND=noninteractive aptitude install --assume-yes mysql-server
aptitude install --assume-yes --allow-untrusted libdbd-mysql-perl libopenxpki-perl openxpki-i18n

echo " 
CREATE database openxpki;
CREATE USER 'openxpki'@'localhost' IDENTIFIED BY 'openxpki';
GRANT ALL ON openxpki.* TO 'openxpki'@'localhost';
flush privileges;" | mysql -u root

#Setup the database
openxpkiadm loadcfg
openxpkiadm initdb

# create certificates 
bash /usr/share/doc/libopenxpki-perl/examples/sampleconfig.sh

# Start
openxpkictl start

