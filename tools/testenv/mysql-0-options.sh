#!/usr/bin/env bash

_BASE_OPTS=()
DB_OPTS_ROOT=()
DB_OPTS_OXI=()

# If we are root and DB is on localhost/127.0.0.1, we assume that socket
# connection is available and ignore host and port
if [[ $(id -u) != 0 || ( "$OXI_TEST_DB_MYSQL_DBHOST" != "127.0.0.1" && "$OXI_TEST_DB_MYSQL_DBHOST" != "localhost" ) ]]; then
    test ! -z "$OXI_TEST_DB_MYSQL_DBHOST" && _BASE_OPTS=("${_BASE_OPTS[@]}" -h "$OXI_TEST_DB_MYSQL_DBHOST") || true
    test ! -z "$OXI_TEST_DB_MYSQL_DBPORT" && _BASE_OPTS=("${_BASE_OPTS[@]}" -P "$OXI_TEST_DB_MYSQL_DBPORT") || true
fi

DB_OPTS_ROOT=("${_BASE_OPTS[@]}" -u"$OXI_TEST_DB_MYSQL_DBUSER")
test ! -z "$OXI_TEST_DB_MYSQL_DBPASSWORD" && DB_OPTS_ROOT=("${DB_OPTS_ROOT[@]}" -p"$OXI_TEST_DB_MYSQL_DBPASSWORD") || true

DB_OPTS_OXI=("${_BASE_OPTS[@]}" -u"$OXI_TEST_DB_MYSQL_USER")
test ! -z "$OXI_TEST_DB_MYSQL_PASSWORD" && DB_OPTS_OXI=("${DB_OPTS_OXI[@]}" -p"$OXI_TEST_DB_MYSQL_PASSWORD") || true
