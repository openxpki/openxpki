#!/bin/sh

MAKE=gmake
MAIN_DIR=`cd ../../../.. && pwd`
TARBALLS_DIR=${MAIN_DIR}
echo MAIN_DIR is ${MAIN_DIR} 
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

echo Your TARBALLS have gone into directory ${TARBALLS_DIR}
exit

