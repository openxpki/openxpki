#!/bin/sh

MAJOR_VERSION="0.9"

MAIN_DIR=`cd ../../../.. && pwd`
PORTS="${MAIN_DIR}/openxpki/trunk/package/freebsd/usr/ports"
TARBALLS_DIR="${PORTS}/distfiles/openxpki"
PORTFILE="${PORTS}/security/p5-openxpki/Makefile"
MAKE=gmake
MV="mv -f"

make-clean () {
if test -f Makefile; then ${MAKE} clean
fi
if test -f Makefile.old; then rm -f *.old
fi
}

rm -rf ${MAIN_DIR}/*.tar.gz
rm -rf ${MAIN_DIR}/*.tgz

#---------------- SERVER ----------------------

SERVER_DIR="openxpki/trunk/perl-modules/core/trunk"
TAR_SERVER_DIR="perl_modules"

if ! test -d ${MAIN_DIR}/${SERVER_DIR}; then
    echo "Error: directory ${MAIN_DIR}/${SERVER_DIR} does not exist"
    exit 1;
fi

cd ${MAIN_DIR}/${SERVER_DIR}

make-clean

perl Makefile.PL && \
${MAKE} dist

${MV} *.gz ${TARBALLS_DIR}/

make-clean

#---------------- CLIENTS ----------------------

CLIENTS_COMMON_DIR="openxpki/trunk/clients/perl"
CLIENTS="OpenXPKI-Client \
	OpenXPKI-Client-CLI \
	OpenXPKI-Client-HTML-Mason \
	OpenXPKI-Client-SCEP \
	OpenXPKI-Client-SOAP-Lite"

for CLIENT_NAME in ${CLIENTS}
do
    CLIENT_DIR=${MAIN_DIR}/${CLIENTS_COMMON_DIR}/${CLIENT_NAME}
    if test -d ${CLIENT_DIR}; then
        echo =================================================================
        echo fixing directory: ${CLIENT_DIR}
        echo =================================================================
        cd ${CLIENT_DIR}
        make-clean
	perl Makefile.PL
        ${MAKE} dist
	${MV} *.gz ${TARBALLS_DIR}/
        make-clean
    fi
done

#---------------- DEPLOYMENT----------------------

COMMON_DIR="openxpki/trunk"
OTHER_DIRS="deployment"

for DIR in ${OTHER_DIRS}
do
	cd ${MAIN_DIR}/${COMMON_DIR}/${DIR}
	make-clean
	${MAKE} -f Makefile.in dist
        ${MV} *.gz ${TARBALLS_DIR}/
	make clean	
done

#---------------- i18n ----------------------

COMMON_DIR="openxpki/trunk"
OTHER_DIRS="i18n"

for DIR in ${OTHER_DIRS}
do
	cd ${MAIN_DIR}/${COMMON_DIR}/${DIR}
	make-clean
	${MAKE} dist
        ${MV} *.gz ${TARBALLS_DIR}/
	make clean	
done

#---------------- Makefile for port ----------------------

cd ${TARBALLS_DIR}
S=`ls OpenXPKI-${MAJOR_VERSION}.*.gz`
C1=`ls OpenXPKI-Client-${MAJOR_VERSION}.*.gz`
C2=`ls OpenXPKI-Client-SCEP-${MAJOR_VERSION}.*.gz`
C3=`ls OpenXPKI-Client-SOAP-Lite-${MAJOR_VERSION}.*.gz`
C4=`ls OpenXPKI-Client-CLI-${MAJOR_VERSION}.*.gz`
C5=`ls OpenXPKI-Client-HTML-Mason-${MAJOR_VERSION}.*.gz`
D=`ls openxpki-deployment-${MAJOR_VERSION}.*.gz`
I=`ls openxpki-i18n-${MAJOR_VERSION}.*.gz`

MINOR_VERSION=`echo $S | sed -e "s/OpenXPKI-${MAJOR_VERSION}\.\(.*\)\.tar\.gz/\1/"`

sed \
 -e "s/\(PORTVERSION=	${MAJOR_VERSION}\.\).*$/\1${MINOR_VERSION}/" \
 -e "s/OpenXPKI-${MAJOR_VERSION}\..*\.gz/${S}/" \
 -e "s/OpenXPKI-Client-${MAJOR_VERSION}\..*\.gz/${C1}/" \
 -e "s/OpenXPKI-Client-SCEP-${MAJOR_VERSION}\..*\.gz/${C2}/" \
 -e "s/OpenXPKI-Client-SOAP-Lite-${MAJOR_VERSION}\..*\.gz/${C3}/" \
 -e "s/OpenXPKI-Client-CLI-${MAJOR_VERSION}\..*\.gz/${C4}/" \
 -e "s/OpenXPKI-Client-HTML-Mason-${MAJOR_VERSION}\..*\.gz/${C5}/" \
 -e "s/openxpki-deployment-${MAJOR_VERSION}\..*\.gz/${D}/" \
 -e "s/openxpki-i18n-${MAJOR_VERSION}\..*\.gz/${I}/" -i .bak ${PORTFILE}

cd ${PORTS} 
cp -R /usr/ports/Mk .
cd security/p5-openxpki
make makesum PORTSDIR=${PORTS}
rm -r ${PORTS}/Mk

echo Your TARBALLS have gone into directory ${TARBALLS_DIR}
echo Makefile and distinfo files modified in directory ${PORTS}/security/p5-openxpki

exit

