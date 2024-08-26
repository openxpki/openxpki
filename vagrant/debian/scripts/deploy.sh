#!/bin/bash

# Helper to run inside the "develop" vagrant image to copy files from the
# shared /code-repo tree to the actual locations inside the machine

OLDPWD=`pwd`
DIR=`dirname $0`;
cd $DIR;

rsync -c -P -a  /code-repo/core/server/bin/*  /usr/bin/

rsync -c -P -a  /code-repo/core/server/OpenXPKI/*  /usr/lib/x86_64-linux-gnu/perl5/5.28/OpenXPKI/

rsync -a /code-repo/config/* /etc/openxpki/

rsync -a /code-repo/core/server/cgi-bin/*  /usr/lib/cgi-bin/

rsync -a  /code-repo/core/server/htdocs/*  /var/www/openxpki/

test -e /code-repo/core/i18n/en_US/openxpki.mo && ( cp  /code-repo/core/i18n/en_US/openxpki.mo /usr/share/locale/en_US/LC_MESSAGES/ )

service apache2 restart

echo -n "Restart OpenXPKI (y/n)? "

read P

if [ "$P" == "y" ]; then
    openxpkictl restart server
fi

cd $OLDPWD;
