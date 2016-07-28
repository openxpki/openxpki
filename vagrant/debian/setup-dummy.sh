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

if [ -d /opt/myperl/share/examples/ ]; then
    BASE=/opt/myperl/share/examples
else
    BASE=/usr/share/doc/libopenxpki-perl/examples
fi

# same for SQL dump
if [ -f "$BASE/schema-mysql.sql.gz" ]; then
    zcat "$BASE/schema-mysql.sql.gz" | mysql -u root openxpki
else
    mysql -u root openxpki < "$BASE/schema-mysql.sql"
fi

# example script might be packed or not
if [ -f "$BASE/sampleconfig.sh.gz" ]; then
    zcat "$BASE/sampleconfig.sh.gz" | /bin/bash  
else
    /bin/bash "$BASE/sampleconfig.sh"
fi

# Need to pickup new group
/etc/init.d/apache2 restart

# Start
openxpkictl start
