#!/bin/sh
#
# a small wrapper around CreateKeystore.jar for use with OpenXPKI
#
java -cp /path/to/CreateKeystore.jar de.cynops.java.crypto.keystore.CreateKeystore $*
RC=$?
exit $RC
