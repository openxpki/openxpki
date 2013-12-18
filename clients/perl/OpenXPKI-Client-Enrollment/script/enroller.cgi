#!/bin/sh
#
# script/enroller.cgi
#
# If you are using a Perl binary that is not in the PATH,
# setting CGIPATH in your httpd.conf and pointing the URI
# to this script instead of script/enroller will cause
# that script to be called with the desired PATH.
#

target=`dirname $0`/`basename $0 .cgi`

if [ -n "$CGIPATH" ]; then
  export PATH="$CGIPATH"
fi

echo "CGIPATH=$CGIPATH" 1>&2

exec "$target"

  
