#!/usr/bin/env bash

# sets DB_OPTS_ROOT and DB_OPTS_OXI
source $(dirname "${BASH_SOURCE[*]}")/mysql-0-options.sh

echo "MySQL: waiting for DB to initialize (max. 30 seconds)"

TEST_CMD=(mysql -e "quit" --connect_timeout=1 "${DB_OPTS_ROOT[@]}")

sec=0; error=1
while [ $error -ne 0 -a $sec -lt 30 ]; do
    error=$("${TEST_CMD[@]}" 2>&1 | grep -c ERROR)
    sec=$[$sec+1]
    sleep 1
done

if [ $error -ne 0 ]; then
    echo "It seems that the MySQL database was not started. Output:"
    "${TEST_CMD[@]}"
    exit 1
fi
