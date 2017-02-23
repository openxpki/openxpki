#!/bin/bash
# Provision a Vagrant box (VirtualBox VM) for testing and development:
# Install Oracle XE client and set up database
SCRIPT_DIR=/vagrant/assets/oracle

#
# Exit handler
#
LOG=$(mktemp)
function _exit () {
    if [ $1 -ne 0 -a $1 -ne 333 ]; then
        echo "$0: ERROR - last command exited with code $1, output:" >&2 && cat $LOG >&2
    fi
    rm -f $LOG
    exit $1
}
trap '_exit $?' EXIT

#
# Config
#
echo "OXI_TEST_DB_ORACLE_NAME=XE"           >> /etc/environment
echo "OXI_TEST_DB_ORACLE_USER=oxitest"      >> /etc/environment
echo "OXI_TEST_DB_ORACLE_PASSWORD=openxpki" >> /etc/environment
while read def; do export $def; done < /etc/environment

#
# Check if installation package exists
#
if [ ! -f $SCRIPT_DIR/docker/setup/packages/oracle-xe-11.2*.rpm.zip ]; then
    cat <<__ERROR >&2
================================================================================
ERROR - Missing Oracle XE setup file

Please download the Oracle XE 11.2 setup for Linux from
http://www.oracle.com/technetwork/database/database-technologies/express-edition/downloads/index.html
and place it in <vagrant>/assets/oracle/docker/setup/packages/

When you are done, run "vagrant provision" to continue.
================================================================================
__ERROR
    exit 333
fi

#
# Run Docker container
#
echo "Oracle: building and starting Docker container - have a break, this will take a while :)"

docker rm -f oracle >/dev/null 2>&1
set -e
docker build $SCRIPT_DIR/docker -t oracle-image                       >$LOG 2>&1
docker run --name oracle -d -p 1521:1521 -p 1080:8080 oracle-image    >$LOG 2>&1
set +e

#
# Install Oracle client (sqlplus64)
#
installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'oracle-instantclient*' 2>&1 | grep -ci installed)
if [ $installed -eq 0 ]; then
    set -e
    # quiet mode -q=2 implies -y
    echo "Oracle: building and installing client (and required packages)"
    apt-get -q=2 install fakeroot alien libaio1                       >$LOG 2>&1
    fakeroot alien -i $SCRIPT_DIR/oracle-instantclient12.1-*.rpm      >$LOG 2>&1
    echo "/usr/lib/oracle/12.1/client64/lib/" > /etc/ld.so.conf.d/oracle.conf
    ldconfig                                                          >$LOG 2>&1
    set +e

    # Oracle database connection id
    sed "s/%hostname%/$HOSTNAME/g" $SCRIPT_DIR/tnsnames.ora  > /etc/tnsnames.ora

    # Set TNS_ADMIN for sqlplus64 to find tnsnames.ora, ORACLE_HOME for Perl module DBD::Oracle
    echo "export TNS_ADMIN=/etc"                             > /etc/profile.d/oracle.sh
    echo "export ORACLE_HOME=/usr/lib/oracle/12.1/client64" >> /etc/profile.d/oracle.sh
    . /etc/profile

    # DBD::Oracle expects demo.mk there
    ln -s /usr/share/oracle/12.1/client64/demo/demo.mk /usr/share/oracle/12.1/client64/
fi

#
# Wait for database initialization
#
echo "Oracle: waiting for DB in Docker container to initialize (max. 60 seconds)"
sec=0; error=1
while [ $error -ne 0 -a $sec -lt 60 ]; do
    error=$(echo "quit;" | sqlplus64 -s system/oracle@XE | grep -c ORA-)
    sec=$[$sec+1]
    sleep 1
done
if [ $error -ne 0 ]; then
    echo "It seems that the Oracle database was not started. Output:"
    echo "quit;" | sqlplus64 -s system/oracle@XE
    exit 333
fi

#
# Database setup
#
set -e
echo "Oracle: setting up database (user + schema)"

cat <<__SQL | sqlplus64 -s system/oracle@XE                           >$LOG 2>&1
DROP USER $OXI_TEST_DB_ORACLE_USER;
CREATE USER $OXI_TEST_DB_ORACLE_USER IDENTIFIED BY "$OXI_TEST_DB_ORACLE_PASSWORD"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;
GRANT connect, resource TO $OXI_TEST_DB_ORACLE_USER;
QUIT;
__SQL

sqlplus64 $OXI_TEST_DB_ORACLE_USER/$OXI_TEST_DB_ORACLE_PASSWORD@XE \
 @/code-repo/config/sql/schema-oracle.sql                             >$LOG 2>&1
set +e

#
# Install CPANminus and modules
#
if ! which cpanm >/dev/null; then
    echo "Installing cpanm"
    curl -s -L https://cpanmin.us | perl - --sudo App::cpanminus >$LOG 2>&1 || _exit $?
fi
echo "Oracle: installing Perl module"
cpanm --notest DBD::Oracle >$LOG 2>&1 || _exit $?
