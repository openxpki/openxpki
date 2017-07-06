#!/usr/bin/env bash

echo "Creating MySQL database schema"

SCHEMA="$(readlink -e $(dirname $0)/../../config/sql/schema-mysql.sql)"
test ! -z "$1" && SCHEMA="$1"

DBPASS=""
test ! -z "$OXI_TEST_DB_MYSQL_DBPASSWORD" && DBPASS="-p$OXI_TEST_DB_MYSQL_DBPASSWORD" || true

mysql \
    -h $OXI_TEST_DB_MYSQL_DBHOST -P $OXI_TEST_DB_MYSQL_DBPORT \
    -u$OXI_TEST_DB_MYSQL_DBUSER $DBPASS \
    $OXI_TEST_DB_MYSQL_NAME \
    < "$SCHEMA"
