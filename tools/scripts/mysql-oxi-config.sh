#!/usr/bin/env bash

echo "Creating OpenXPKI database configuration"

cat <<__DB > /etc/openxpki/config.d/system/database.yaml
main:
    debug: 0
    type: MySQL
    host: $OXI_TEST_DB_MYSQL_DBHOST
    port: $OXI_TEST_DB_MYSQL_DBPORT
    name: $OXI_TEST_DB_MYSQL_NAME
    user: $OXI_TEST_DB_MYSQL_USER
    passwd: $OXI_TEST_DB_MYSQL_PASSWORD
__DB
