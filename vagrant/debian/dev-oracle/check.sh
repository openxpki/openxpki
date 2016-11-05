#!/bin/bash

set -e

test -f /vagrant/docker/setup/packages/oracle-xe-11.2*.rpm.zip && exit 0

cat <<__ERROR >&2
================================================================================
ERROR - Missing Oracle XE setup file

Please download the Oracle XE 11.2 setup for Linux from
http://www.oracle.com/technetwork/database/database-technologies/express-edition/downloads/index.html
and place it in <vagrant>/docker/setup/packages/

This file cannot be put into the OpenXPKI repository due to license restrictions.
================================================================================
__ERROR

exit 1
