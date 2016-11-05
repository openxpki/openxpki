#!/bin/bash

set -e

# Update hostname because in the container it differs from the built image
sed -i -E "s/HOST = [^)]+/HOST = $HOSTNAME/g" $ORACLE_HOME/network/admin/listener.ora
sed -i -E "s/HOST = [^)]+/HOST = $HOSTNAME/g" $ORACLE_HOME/network/admin/tnsnames.ora

/etc/init.d/oracle-xe start

		#Check for mounted database files
#		if [ "$(ls -A /u01/app/oracle/oradata)" ]; then
#			echo "Found existing database files (/u01/app/oracle/oradata)"
#			echo "XE:$ORACLE_HOME:N" >> /etc/oratab
#			chown oracle:dba /etc/oratab
#			chown 664 /etc/oratab
#			printf "ORACLE_DBENABLED=false\nLISTENER_PORT=1521\nHTTP_PORT=8080\nCONFIGURE_RUN=true\n" > /etc/default/oracle-xe
#			rm -rf /u01/app/oracle-template/11.2.0/xe/dbs
#			ln -s /u01/app/oracle/dbs /u01/app/oracle-template/11.2.0/xe/dbs

echo "Please visit http://<container>:8080/apex to proceed with configuration"

##
## Workaround for graceful shutdown. ....ing oracle... ‿( ́ ̵ _-`)‿
##
while [ "$END" == '' ]; do
	sleep 1
	trap "/etc/init.d/oracle-xe stop && END=1" INT TERM
done
