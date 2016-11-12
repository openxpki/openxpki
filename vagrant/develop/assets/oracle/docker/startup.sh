#!/bin/bash

set -e

# Update hostname because in the container it differs from the built image
sed -i -E "s/HOST = [^)]+/HOST = $HOSTNAME/g" $ORACLE_HOME/network/admin/listener.ora
sed -i -E "s/HOST = [^)]+/HOST = $HOSTNAME/g" $ORACLE_HOME/network/admin/tnsnames.ora

/etc/init.d/oracle-xe start

echo "Please visit http://<container>:8080/apex to proceed with configuration"

# Workaround for graceful shutdown
while [ "$END" == '' ]; do
	sleep 1
	trap "/etc/init.d/oracle-xe stop && END=1" INT TERM
done
