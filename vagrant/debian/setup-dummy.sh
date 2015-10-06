#!/bin/bash

rm -rf /etc/openxpki/ssl/

if [ -x /opt/myperl/bin/openxpkiadm ]; then
    export PATH=/opt/myperl/bin:$PATH
fi

echo " 
DROP database if exists openxpki;
CREATE database openxpki CHARSET utf8;
CREATE USER 'openxpki'@'localhost' IDENTIFIED BY 'openxpki';
GRANT ALL ON openxpki.* TO 'openxpki'@'localhost';
flush privileges;" | mysql -u root

#Setup the database
openxpkiadm initdb

# create certificates
# example script might be packed
test -f /usr/share/doc/libopenxpki-perl/examples/sampleconfig.sh.gz && \
  gunzip /usr/share/doc/libopenxpki-perl/examples/sampleconfig.sh.gz

if [ -f /usr/share/doc/libopenxpki-perl/examples/sampleconfig.sh ]; then
    bash /usr/share/doc/libopenxpki-perl/examples/sampleconfig.sh
fi

if [ -f /opt/myperl/share/examples/sampleconfig.sh ]; then
    bash /opt/myperl/share/examples/sampleconfig.sh
fi

# Need to pickup new group
/etc/init.d/apache2 restart

# Start
openxpkictl start
