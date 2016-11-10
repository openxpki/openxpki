#!/bin/bash

set -e
SCRIPT_DIR=$(dirname $0)

#
# Install dependencies
#
# "initscripts" provides /etc/init.d/functions which is needed by /etc/init.d/oracle-xe
echo "Installing basic dependencies"
rpm --quiet --rebuilddb && yum -q -y install unzip bc initscripts

cd $SCRIPT_DIR
unzip -qq oracle-xe-11*.zip

cd Disk1
echo "Installing Oracle dependencies"
rpm --quiet --rebuilddb && (yum deplist *.rpm | awk '/provider/ {print $2}' | sort -u | xargs yum -q -y install)

#
# Install Oracle DB
#
echo "Installing Oracle database"
rpm --rebuilddb && rpm -i --noscripts *.rpm
rpm -qp --scripts *.rpm > postinstall.sh
sed -i -e '1,/^postinstall scriptlet/ d' -e '/^[a-z][a-z]* scriptlet/,$ d' postinstall.sh
bash postinstall.sh

yum -q clean all
