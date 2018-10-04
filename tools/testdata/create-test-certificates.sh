#!/bin/bash
#
# Create test certificates and import them into OpenXPKI database for later
# use in test code / environment.
#
# The MySQL database should be freshly created, i.e. without any data in it.
# (e.g. using tools/testenv/mysql-create-db.sh && tools/testenv/mysql-create-schema.sh)
#
# The resulting certificates are available in two forms below ./certificates/:
# 1. Perl code to be inserted into OpenXPKI::Test::CertHelper::Database
# 2. A MySQL database dump
#
# The test certificates only need to be regenerated if there are some major
# changes to the project (like certificate algorithm, database schema change etc.)
#
BASEDIR=$(readlink -e $(dirname $0))
TEMPDIR=$(mktemp -d)

set -e

# Steps to create the certificates:
# 1. Setup test OpenXPKI configuration in temporary directory
#    (MySQL config will be read from env vars $OXI_TEST_DB_MYSQL_xxx)
$BASEDIR/_create-config.pl $TEMPDIR

# 2. Create certificates and store them in $TEMPDIR/etc/openxpki/ssl/xxx/
# 3. Import cert. into MySQL using test config above
$BASEDIR/_create-certs.sh  $TEMPDIR/etc/openxpki

# 4. Create Perl code for OpenXPKI::Test::CertHelper::Database
$BASEDIR/_pem-to-certhelper.pl $TEMPDIR/etc/openxpki/ssl > $BASEDIR/certificates/certhelper-code.pl
$BASEDIR/_db-to-certhelper.pl                           >> $BASEDIR/certificates/certhelper-code.pl
echo ""
echo "Code for OpenXPKI::Test::CertHelper::Database is available in:"
echo "    $BASEDIR/certificates/certhelper-code.pl"

# 5. Create MySQL dump
mysqldump -h $OXI_TEST_DB_MYSQL_DBHOST -u $OXI_TEST_DB_MYSQL_USER -p"$OXI_TEST_DB_MYSQL_PASSWORD" \
    --set-charset --no-create-info \
    --skip-comments --skip-add-locks --skip-disable-keys \
    --extended-insert --complete-insert --single-transaction \
    $OXI_TEST_DB_MYSQL_NAME > $BASEDIR/certificates/mysql-dump.sql
echo ""
echo "MySQL insert script is available in:"
echo "    $BASEDIR/certificates/mysql-dump.sql"

rm -rf $TEMPDIR

echo "Done"
