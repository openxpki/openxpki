#!/bin/bash

rm -rf /etc/openxpki/ssl/

echo " 
DROP database if exists openxpki;
CREATE database openxpki;
CREATE USER 'openxpki'@'localhost' IDENTIFIED BY 'openxpki';
GRANT ALL ON openxpki.* TO 'openxpki'@'localhost';
flush privileges;" | mysql -u root

#Setup the database
openxpkiadm loadcfg
openxpkiadm initdb

# create certificates 
bash /usr/share/doc/libopenxpki-perl/examples/sampleconfig.sh

# Need to pickup new group 
/etc/init.d/apache2 restart

# Start
openxpkictl start

