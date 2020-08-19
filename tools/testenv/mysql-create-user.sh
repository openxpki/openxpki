#!/usr/bin/env bash

# sets DB_OPTS_ROOT and DB_OPTS_OXI
source $(dirname "${BASH_SOURCE[*]}")/mysql-0-options.sh

echo "MySQL: creating user"

cat <<__SQL | mysql "${DB_OPTS_ROOT[@]}"
CREATE USER '$OXI_TEST_DB_MYSQL_USER'@'%' IDENTIFIED BY '$OXI_TEST_DB_MYSQL_PASSWORD';
GRANT ALL ON $OXI_TEST_DB_MYSQL_NAME.* TO '$OXI_TEST_DB_MYSQL_USER'@'%';
flush privileges;
__SQL

# Create hardcoded frontend session user
cat <<__SQL | mysql "${DB_OPTS_ROOT[@]}"
CREATE USER 'openxpki_session'@'%' IDENTIFIED BY 'mysecret';
__SQL
