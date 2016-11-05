#!/bin/bash

set -e
SCRIPT_DIR=$(dirname $0)

#
# Modify config
# (Oracle's default of sessions=20 would crash the setup script below)
#
sed -ri 's/^(memory_target\s*=.*)$/#\1\npga_aggregate_target=200540160\nsga_target=601620480/' \
  $ORACLE_HOME/config/scripts/init.ora
sed -ri 's/^sessions\s*=.*$/processes=500\nsessions=555\ntransactions=610/' \
  $ORACLE_HOME/config/scripts/init.ora
sed -ri 's/^(memory_target\s*=.*)$/#\1\npga_aggregate_target=200540160\nsga_target=601620480/' \
  $ORACLE_HOME/config/scripts/initXETemp.ora
sed -ri 's/^sessions\s*=.*$/processes=500\nsessions=555\ntransactions=610/' \
  $ORACLE_HOME/config/scripts/initXETemp.ora

#
# Setup database (takes a long time)
#
echo "Configuring and starting database"
printf 8080\\n1521\\noracle\\noracle\\nn\\n | /etc/init.d/oracle-xe configure

#
# Enable remote access
#
echo "Enabling remote access"
echo "alter system disable restricted session;" | sqlplus -s SYSTEM/oracle@$ORACLE_SID

/etc/init.d/oracle-xe stop
