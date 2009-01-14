#!/bin/sh
MOUNTPOINT=$1
if [ "$MOUNTPOINT" == "" ]; then
    echo "Usage: $0 <mountpoint>"
    exit 1
fi
if [ -e ${MOUNTPOINT}/openxpki_live.ext2 ]; then
    echo "openxpki_live.ext2 already exists, will not overwrite it. If you really want to deploy freshly, delete ${MOUNTPOINT}/openxpki_live.ext2"
    exit 1
fi
echo "Redeploying OpenXPKI, this will take a while"
# clear the current databases and remove config
openxpkiadm initdb --force
rm /var/openxpki/sqlite.db*
rm -r /etc/openxpki/instances/trustcenter1/*
# stop networking, the user should be on the console anyways ...
/etc/init.d/networking stop
# reconfigure
dpkg-reconfigure openxpki-deployment
# we are left with SQLite again, redeploy with MySQL
rm /etc/openxpki/instances/trustcenter1/database.xml
rm /etc/openxpki/instances/trustcenter1/log_database.xml
openxpki-configure --batch -- -setcfg database.type=MySQL --setcfg database.name=openxpki --setcfg database.host=localhost --setcfg database.port=3306 --setcfg database.user=openxpki --setcfg database.passwd=pki
# migrate password and aliases from sqlite database to MySQL
(echo '.mode insert'; echo 'select * from certificate;')|sqlite3 /var/openxpki/sqlite.db._backend_|sed -e 's/INSERT INTO table/INSERT INTO certificate/'|mysql -uopenxpki -ppki openxpki
(echo '.mode insert'; echo 'select * from aliases;')|sqlite3 /var/openxpki/sqlite.db._backend_|sed -e 's/INSERT INTO table/INSERT INTO aliases/'|mysql -uopenxpki -ppki openxpki
/etc/init.d/openxpkid stop
/etc/init.d/apache stop
/etc/init.d/mysql stop
# create 100 MB image
dd if=/dev/zero of=${MOUNTPOINT}/openxpki_live.ext2 count=200000 || (echo "Problem creating 100 MB image - no space left on device?"; exit 1)
mkfs.ext2 -F ${MOUNTPOINT}/openxpki_live.ext2
losetup /dev/loop0 ${MOUNTPOINT}/openxpki_live.ext2
mkdir /mnt/loop
mount /dev/loop0 /mnt/loop
# copy config and MySQL database to image, create symbolic links
mkdir -p /mnt/loop/openxpki_live/etc/mysql
mkdir -p /mnt/loop/openxpki_live/etc/openxpki
mkdir -p /mnt/loop/openxpki_live/var/lib/mysql
cp -ar /etc/openxpki/* /mnt/loop/openxpki_live/etc/openxpki
cp -ar /var/lib/mysql/* /mnt/loop/openxpki_live/var/lib/mysql
cp -ar /etc/mysql/* /mnt/loop/openxpki_live/etc/mysql
rm -rf /etc/mysql
ln -s /mnt/loop/openxpki_live/etc/mysql /etc/mysql
rm -rf /var/lib/mysql
ln -s /mnt/loop/openxpki_live/var/lib/mysql /var/lib/mysql
rm -rf /etc/openxpki
ln -s /mnt/loop/openxpki_live/etc/openxpki /etc/openxpki
/etc/init.d/mysql start
/etc/init.d/openxpkid start
/etc/init.d/apache start
echo "Successfully redeployed to ${MOUNTPOINT}, you should now be able to use a persistent OpenXPKI"
