#!/usr/bin/env bash

# sets DB_OPTS_ROOT and DB_OPTS_OXI
source $(dirname "${BASH_SOURCE[*]}")/mysql-0-options.sh

echo "MySQL: creating database"

cat <<__SQL | mysql "${DB_OPTS_ROOT[@]}"
DROP database IF EXISTS $OXI_TEST_DB_MYSQL_NAME;
CREATE database $OXI_TEST_DB_MYSQL_NAME CHARSET utf8;
__SQL
