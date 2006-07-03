#!/bin/sh

MAKE=gmake
MAIN_DIR=`cd ../../../.. && pwd`
echo MAIN_DIR is $MAIN_DIR 
MV="mv -f"

make-clean () {
if test -f Makefile; then ${MAKE} clean
fi
if test -f Makefile.old; then rm -f *.old
fi
}

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
${MAKE} && \
${MAKE} dist

S_DIST=`ls * | grep ".gz"`
TAR_DIR=`echo ${S_DIST} | sed -e 's/.tar.gz//'`

if test -z ${TAR_DIR}; then 
    echo "Error: problems making dist in ${MAIN_DIR}/${SERVER_DIR}"
    exit 1;
fi

if test -d ${MAIN_DIR}/${TAR_DIR}; then
    echo "Warning: directory ${MAIN_DIR}/${TAR_DIR} already exists. Overwriting ..."
    rm -R ${MAIN_DIR}/${TAR_DIR}
fi

mkdir ${MAIN_DIR}/${TAR_DIR}
${MV}  ${MAIN_DIR}/${SERVER_DIR}/${S_DIST} ${MAIN_DIR}/${TAR_DIR}/
make-clean
cd ${MAIN_DIR}/${TAR_DIR}
tar xzf ${S_DIST}
${MV} ${TAR_DIR} ${TAR_SERVER_DIR}
rm *.gz

#---------------- CLIENTS ----------------------
# We are in ${MAIN_DIR}/${TAR_DIR} now

CLIENTS_COMMON_DIR="openxpki/trunk/clients/perl"
CLIENTS="OpenXPKI-Client OpenXPKI-Client-CLI OpenXPKI-Client-HTML-Mason OpenXPKI-Client-SCEP OpenXPKI-Client-SOAP-Lite"
TAR_CLIENTS_COMMON_DIR="clients"

mkdir ${TAR_CLIENTS_COMMON_DIR}
for CLIENT_NAME in ${CLIENTS}
do
    CLIENT_DIR=${MAIN_DIR}/${CLIENTS_COMMON_DIR}/${CLIENT_NAME}
    if test -d ${CLIENT_DIR}; then
        echo =================================================================
        echo fixing directory: ${CLIENT_DIR}
        echo =================================================================
#        sleep 5
        cd ${CLIENT_DIR}
        make-clean
        perl Makefile.PL
        ${MAKE} dist
        CL_DIST=`ls * | grep ".gz"`
        if test ${CL_DIST}; then
            echo "CL_DIST = ${CL_DIST}"
#            sleep 5
            ${MV} ${CLIENT_DIR}/${CL_DIST} ${MAIN_DIR}/${TAR_DIR}/${TAR_CLIENTS_COMMON_DIR}/
            cd ${MAIN_DIR}/${TAR_DIR}/${TAR_CLIENTS_COMMON_DIR}
            tar xzf ${CL_DIST}
            TAR_CLIENT_DIR=`echo ${CL_DIST} | sed -e 's/.tar.gz//'`
            ${MV} ${TAR_CLIENT_DIR} ${CLIENT_NAME}
            rm *.gz
        fi
        cd ${CLIENT_DIR}
        make-clean
    fi
done

#---------------- DOCS and DEPLOYMENT----------------------

COMMON_DIR="openxpki/trunk"
OTHER_DIRS="deployment docs"

for DIR in ${OTHER_DIRS}
do
    cp -r ${MAIN_DIR}/${COMMON_DIR}/${DIR} ${MAIN_DIR}/${TAR_DIR}/
    cd ${MAIN_DIR}/${TAR_DIR}/${DIR}
    make-clean
    FILES=`find . -name "CVS" -or -name ".svn"`
    echo Filelist: ${FILES}
    for F in ${FILES}
    do
        if test -d $F; then rm -fr $F
        fi
    done
done

cd ${MAIN_DIR}
rm -f ${TAR_DIR}.tar.*
tar cHf ${TAR_DIR}.tar ${TAR_DIR}
#bzip2 --keep --best ${TAR_DIR}.tar
gzip --best ${TAR_DIR}.tar
#rm -rf ${MAIN_DIR}/${TAR_DIR}

exit

