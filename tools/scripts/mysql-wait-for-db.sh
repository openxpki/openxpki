#!/usr/bin/env bash

echo "Waiting for MySQL to initialize (max. 60 seconds)"

TEST_CMD=(mysql -e "quit" --connect_timeout=1 -h $OXI_TEST_DB_MYSQL_DBHOST -P $OXI_TEST_DB_MYSQL_DBPORT -u$OXI_TEST_DB_MYSQL_DBUSER)
test ! -z "$OXI_TEST_DB_MYSQL_DBPASSWORD" && TEST_CMD=("${TEST_CMD[@]}" -p$OXI_TEST_DB_MYSQL_DBPASSWORD) || true

sec=0; error=1
while [ $error -ne 0 -a $sec -lt 60 ]; do
    error=$("${TEST_CMD[@]}" 2>&1 | grep -c ERROR)
    sec=$[$sec+1]
    sleep 1
done

if [ $error -ne 0 ]; then
    echo "It seems that the MySQL database was not started. Output:"
    "${TEST_CMD[@]}"
    exit 1
fi
