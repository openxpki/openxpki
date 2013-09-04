#!/bin/sh
##
## Written 2006 by Julia Dubenskaya and Sergei Vyshenski
## for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

MAJOR_VERSION="0.9"

MAIN_DIR=`cd ../../../.. && pwd`
MAIN_PORTS_DIR="/usr/ports"
PORTS_DIR="${MAIN_DIR}/openxpki/trunk/package/freebsd/${MAIN_PORTS_DIR}"
TARBALLS_DIR="${PORTS_DIR}/distfiles/openxpki"
MAKE=gmake
MV="mv -f"
BSD_FILES="bsd.openssl.mk bsd.port.mk bsd.sites.mk"

make-clean () {
if test -f Makefile; then ${MAKE} clean
fi
if test -f Makefile.old; then rm -f *.old
fi
}

if [ -e ${PORTS_DIR}/Mk ]; then
    if [ -d ${PORTS_DIR}/Mk -o -h ${PORTS_DIR}/Mk ]; then
        echo "Link or directory ${PORTS_DIR}/Mk already exists";
        for BSD_FILE in ${BSD_FILES}; do
            if [ ! -f ${PORTS_DIR}/Mk/${BSD_FILE} ]; then
                echo "File ${BSD_FILE} is absent from ${PORTS_DIR}/Mk"
                exit 1
            fi
        done
        echo "All needed files are present in ${PORTS_DIR}/Mk";
    else
        echo "${PORTS_DIR}/Mk exists" 
        echo "but it is not a symbolic link or directory"
        exit 1
    fi
else
    echo "Link directory ${PORTS_DIR}/Mk does not exist";
    if [ ! -d ${MAIN_PORTS_DIR} ]; then
        echo "Directory ${MAIN_PORTS_DIR}/Mk does not exist too";
        echo "Please provide directory ${PORTS_DIR}/Mk with files:"
        for BSD_FILE in ${BSD_FILES}; do
            echo "${BSD_FILE}"
        done
        exit 1
    else 
        echo "Soft link ${PORTS_DIR}/Mk will be created"
        ln -s ${MAIN_PORTS_DIR}/Mk ${PORTS_DIR}/Mk
    fi
fi

rm -rf ${TARBALLS_DIR}/*
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
	OpenXPKI-Client-HTML-Mason \
	OpenXPKI-Client-SCEP"

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
	./configure --distonly
	${MAKE} dist
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

PORTS_PREFIX="p5-"
PORTS="openxpki openxpki-client openxpki-client-html-mason openxpki-client-scep openxpki-i18n openxpki-deployment"

cd ${PORTS_DIR} 
MODIFIED_PORTS=0

for PORT in ${PORTS}; do
    cd ${TARBALLS_DIR}
    TARBALL_NAME=`find . -iname ${PORT}-${MAJOR_VERSION}.*.gz | sed -e "s/\.\///"`
    PORT_NAME=`echo ${TARBALL_NAME} | sed -e "s/\(^.*\)-${MAJOR_VERSION}\..*\.tar\.gz/\1/"`
    NEW_MINOR_VERSION=`echo ${TARBALL_NAME} | sed -e "s/${PORT_NAME}-${MAJOR_VERSION}\.\(.*\)\.tar\.gz/\1/"`
    PORT_MAKEFILE="${PORTS_DIR}/security/${PORTS_PREFIX}${PORT}/Makefile"
    PREV_MINOR_VERSION=`grep "PORTVERSION=" ${PORT_MAKEFILE} | sed -e "s/PORTVERSION=	${MAJOR_VERSION}\.\(.*$\)/\1/"`
    if [ ${NEW_MINOR_VERSION} != ${PREV_MINOR_VERSION} ]; then
        MODIFIED_PORTS=`expr ${MODIFIED_PORTS} + 1`
        echo "${MODIFIED_PORTS}.Updating port ${PORTS_PREFIX}${PORT}: previous version = ${PREV_MINOR_VERSION}, new version = ${NEW_MINOR_VERSION}."
        sed \
            -e "s/\(PORTVERSION=	${MAJOR_VERSION}\.\).*$/\1${NEW_MINOR_VERSION}/" \
            -e "s/${PORT_NAME}-${MAJOR_VERSION}\..*\.gz/${TARBALL_NAME}/" -i .bak ${PORT_MAKEFILE}
    
        cd ${PORTS_DIR}/security/${PORTS_PREFIX}${PORT}/
        make makesum PORTSDIR=${PORTS_DIR}
    else
        rm -rf ${TARBALLS_DIR}/${TARBALL_NAME}
    fi
done

echo Your TARBALLS have gone into directory ${TARBALLS_DIR}
echo "Makefile and distinfo files modified in ${MODIFIED_PORTS} ports in directory ${PORTS_DIR}/security/"

exit

