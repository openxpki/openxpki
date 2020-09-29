#!/usr/bin/env bash

# sets DB_OPTS_ROOT and DB_OPTS_OXI
source $(dirname "${BASH_SOURCE[*]}")/mysql-0-options.sh

echo "MySQL: creating schema"

if [ -z $OXI_TEST_SAMPLECONFIG_DIR ]; then
    echo "ERROR: variables OXI_TEST_SAMPLECONFIG_DIR is not set"
    exit 1
fi

SCHEMA="$OXI_TEST_SAMPLECONFIG_DIR/contrib/sql/schema-mariadb.sql"

mysql "${DB_OPTS_ROOT[@]}" $OXI_TEST_DB_MYSQL_NAME < "$SCHEMA"

# Give privileges to hardcoded frontend session user (must be done after table creation)
cat <<__SQL | mysql "${DB_OPTS_ROOT[@]}"
GRANT SELECT, INSERT, UPDATE, DELETE ON $OXI_TEST_DB_MYSQL_NAME.frontend_session TO 'openxpki_session'@'%';
flush privileges;
__SQL
