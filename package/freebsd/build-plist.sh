#!/bin/sh
##
## Written 2006 by Julia Dubenskaya and Sergei Vyshenski
## for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
## Based on the example of pkg-plist building 
## from the FreeBSD Porter's Handbook:
## http://www.freebsd.org/doc/en_US.ISO8859-1/books/porters-handbook/
##
## Prepare preliminary version of pkg-plist for port.
## cd to the port directory before starting this script.

set -e
WD=`pwd`
PORT_NAME=`make -V PORTNAME`
TMP=${HOME}/tmp/${PORT_NAME}
rm -rf ${TMP}
mkdir -p ${TMP}
echo ${TMP}

mtree -U -f $(make -V MTREE_FILE) -d -e -p ${TMP}
(cd ${TMP} && find -d * -type d) | sort > OLD-DIRS

touch pkg-plist

export PREFIX=${TMP}
export PORTSDIR="${WD}/../../"
export DISTDIR="${WD}/../../distfiles/"
export DEPENDS_TARGET=""
export INSTALL_AS_USER="yes"
export NO_PKG_REGISTER="yes"
export OLD_SECURITY_CHECK="yes"

make clean
if [ ${PORT_NAME} = 'openxpki-deployment' ]; then
  make extract
  myWRKSRC=`make -V WRKSRC`
  sed -i.bak \
      -e 's|\(ERRORS=1\)|# \1|g' \
      ${myWRKSRC}/configure

  sed -i.bak \
      -e 's|\(^.*\)\(OpenXPKI::VERSION\)|# \1\2|g' \
      ${myWRKSRC}/bin/openxpki-metaconf
fi
make

make install PREFIX=${TMP} 
(cd ${TMP} && find -d * \! -type d \! -path "etc/rc.d/*") | sort > pkg-plist

(cd ${TMP} && find -d * -type d) | sort | \
  comm -13 OLD-DIRS - | sort -r | sed -e 's#^#@dirrm #' >> pkg-plist
rm OLD-DIRS
