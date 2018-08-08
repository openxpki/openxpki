#!/usr/bin/env bash

echo "MySQL: creating schema"

SCHEMA="$(readlink -e $(dirname $0)/../../config/sql/schema-mysql.sql)"
test ! -z "$1" && SCHEMA="$1"

DBPASS=""
test ! -z "$OXI_TEST_DB_MYSQL_DBPASSWORD" && DBPASS="-p$OXI_TEST_DB_MYSQL_DBPASSWORD" || true

mysql \
    -h $OXI_TEST_DB_MYSQL_DBHOST -P $OXI_TEST_DB_MYSQL_DBPORT \
    -u$OXI_TEST_DB_MYSQL_DBUSER $DBPASS \
    $OXI_TEST_DB_MYSQL_NAME \
    < "$SCHEMA"

# Give privileges to hardcoded frontend session user (must be done after table creation)
cat <<__SQL | mysql -h $OXI_TEST_DB_MYSQL_DBHOST -P $OXI_TEST_DB_MYSQL_DBPORT -u$OXI_TEST_DB_MYSQL_DBUSER $DBPASS
GRANT SELECT, INSERT, UPDATE, DELETE ON $OXI_TEST_DB_MYSQL_NAME.frontend_session TO 'openxpki_session'@'%';
flush privileges;
__SQL
