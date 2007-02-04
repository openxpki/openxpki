#!/bin/sh
##
## Written 2006 by Julia Dubenskaya
## for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

set -e

myPWD=`pwd`
PKGNAME_PREFIX="p5-"
MAJOR_VERSION="0.9"
PORT_PATH="/usr/ports/security"
DISTS_PATH="/usr/ports/distfiles/openxpki"
PORT_NAME_SHORT=$1
PORT_NAME_SHORT=`echo ${PORT_NAME_SHORT} | sed -e "s/^${PKGNAME_PREFIX}//"`
PORT_NAME=${PKGNAME_PREFIX}${PORT_NAME_SHORT}
TMP=${HOME}/tmp/${PORT_NAME_SHORT}

if [ ! -d ${myPWD}/${PORT_PATH}/${PORT_NAME} ]; then
  echo -e "Usage: update-port.sh PORT_NAME. \nPossible values of PORT_NAME:\n$(cd ${myPWD}/${PORT_PATH}/ && ls | grep ${PKGNAME_PREFIX})"
  exit 1
fi

if [ -d ${TMP} ]; then
  rm -rf ${TMP} 
fi

cd ${myPWD}/${DISTS_PATH}/
TARBALL_NAME=`find . -iname ${PORT_NAME_SHORT}-${MAJOR_VERSION}.*\.gz | sed -e "s/\.\///"`
if [ ${TARBALL_NAME} ]; then
  echo "New tarball is " ${TARBALL_NAME}
else
  echo "No new tarball for the port ${PORT_NAME} was found in"
  echo "${myPWD}/${DISTS_PATH}/"
  echo "Port was not updated."
  exit 1
fi

echo "========================================================="
echo "Building pkg-plist"
echo "========================================================="
cp ${myPWD}/build-plist.sh ${myPWD}/${PORT_PATH}/${PORT_NAME}/
cd ${myPWD}/${PORT_PATH}/${PORT_NAME}/

./build-plist.sh
rm ${myPWD}/${PORT_PATH}/${PORT_NAME}/build-plist.sh

mv pkg-plist pkg-plist.0
mv Makefile Makefile.bak

${myPWD}/get-final-plist.pl ${PORT_NAME_SHORT}
echo "pwd = " $(pwd)
export NOCLEANDEPENDS="yes"
make clean
rm Makefile.bak
rm pkg-plist.0

if [ -d ${TMP} ]; then
  rm -rf ${TMP} 
fi
