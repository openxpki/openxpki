#!/bin/sh

set -e

OPENSSL_SOURCEDIR="/usr/local/src/openssl/work_098d"
OPENSSL_INSTALLDIR="/usr/local/openssl-0.9.8d-patched"
MAKE=gmake

OPENSSL_VERSION="0.9.8d"
OPENSSL_NAME="openssl-${OPENSSL_VERSION}"
ENGINE_ID="gost"
ENGINE_NAME="engine-${ENGINE_ID}-20061110"
PATCH="openssl-asymm-${OPENSSL_VERSION}-20061110.diff"
OPENSSL_DOWNLOAD="http://www.openssl.org/source/${OPENSSL_NAME}.tar.gz"
ENGINE_DOWNLOAD="http://osdn.dl.sourceforge.net/openxpki/${ENGINE_NAME}.tar.gz"
PATCH_DOWNLOAD="http://osdn.dl.sourceforge.net/openxpki/${PATCH}.gz"
SLEEP_TIME=2

if [ ! -d ${OPENSSL_SOURCEDIR} ]; then
   mkdir -p ${OPENSSL_SOURCEDIR}
fi

cd ${OPENSSL_SOURCEDIR}

echo "+-------------------------- +"
echo "| Getting sources if needed |"
echo "+-------------------------- +"
sleep ${SLEEP_TIME}

if [ ! -f ${OPENSSL_NAME}.tar.gz ]; then
    wget ${OPENSSL_DOWNLOAD}
fi

if [ ! -f ${ENGINE_NAME}.tar.gz ]; then
    wget ${ENGINE_DOWNLOAD}
fi

if [ ! -f ${PATCH}.gz ]; then
    wget ${PATCH_DOWNLOAD}
fi

for file in ${OPENSSL_NAME}.tar.gz ${ENGINE_NAME}.tar.gz ${PATCH}.gz; do
    if [ ! -f ${file} ]; then
        echo "! Error: failed to download ${file}"
        echo "! Please download this file manually and put it to:"
        echo "    ${OPENSSL_SOURCEDIR}/"
        exit
    fi
done

echo "+------------------ +"
echo "| Preparing sources |"
echo "+------------------ +"
sleep ${SLEEP_TIME}

if [ -d ${OPENSSL_NAME} ]; then
    rm -rf ${OPENSSL_NAME}
fi

if [ -d ${ENGINE_NAME} ]; then
    rm -rf ${ENGINE_NAME}
fi

if [ ! -f ${PATCH} ]; then
    gunzip ${PATCH}.gz
fi

if [ ! -d ${OPENSSL_INSTALLDIR} ]; then
   mkdir -p ${OPENSSL_INSTALLDIR}
else
   rm -rf ${OPENSSL_INSTALLDIR}/*
fi

tar xzf ${OPENSSL_NAME}.tar.gz
tar xzf ${ENGINE_NAME}.tar.gz

echo "+------------------------ +"
echo "| Patching OpenSSL-${OPENSSL_VERSION} |"
echo "+------------------------ +"
sleep ${SLEEP_TIME}

cd ${OPENSSL_SOURCEDIR}/${OPENSSL_NAME}
patch -p0 < ../${PATCH}

echo "+---------------------------------------------------- +"
echo "| Configuring OpenSSL-${OPENSSL_VERSION} with ${ENGINE_ID} engine support |"
echo "+---------------------------------------------------- +"
sleep ${SLEEP_TIME}

./config shared --prefix=${OPENSSL_INSTALLDIR} --openssldir=${OPENSSL_INSTALLDIR} -Wl,-rpath,${OPENSSL_INSTALLDIR}/lib -L${OPENSSL_INSTALLDIR}/lib

echo "+-------------------------------------------------------------- +"
echo "| Making and installing OpenSSL-${OPENSSL_VERSION} with ${ENGINE_ID} engine support |"
echo "+-------------------------------------------------------------- +"
sleep ${SLEEP_TIME}

${MAKE} && ${MAKE} test && ${MAKE} install

echo "+----------------------------------------- +"
echo "| Making and installing ${ENGINE_ID} engine itself |"
echo "+----------------------------------------- +"
sleep ${SLEEP_TIME}

cd ${OPENSSL_SOURCEDIR}/${ENGINE_NAME}
${MAKE} OPENSSL_DIR=../${OPENSSL_NAME} LDFLAGS="-g -L${OPENSSL_INSTALLDIR}/lib -R${OPENSSL_INSTALLDIR}/lib -Wl,-rpath,${OPENSSL_INSTALLDIR}/lib -static-libgcc"

if [ -f ${OPENSSL_SOURCEDIR}/${ENGINE_NAME}/lib${ENGINE_ID}.so ]; then
    cp ${OPENSSL_SOURCEDIR}/${ENGINE_NAME}/lib${ENGINE_ID}.so ${OPENSSL_INSTALLDIR}/lib/engines/
else
    echo "! Error: the engine file lib${ENGINE_ID}.so was not created in"
    echo "    ${OPENSSL_SOURCEDIR}/${ENGINE_NAME}/"
    echo "! Please check the previous output and try to make and install"
    echo "! lib${ENGINE_ID}.so manually"
    exit
fi

echo "+------------------------------------------------------------------------------------ +"
echo "| Modifying ${OPENSSL_INSTALLDIR}/openssl.cnf file to support ${ENGINE_ID} engine |"
echo "+------------------------------------------------------------------------------------ +"
sleep ${SLEEP_TIME}

echo "openssl_conf = openssl_def" > ./openssl.cnf.1
cat ${OPENSSL_INSTALLDIR}/openssl.cnf >> ./openssl.cnf.1
echo "" >> ./openssl.cnf.1
echo "[openssl_def]" >> ./openssl.cnf.1
echo "engines = engine_section" >> ./openssl.cnf.1
echo "[engine_section]" >> ./openssl.cnf.1
echo "${ENGINE_ID} = ${ENGINE_ID}_section" >> ./openssl.cnf.1
echo "[${ENGINE_ID}_section]" >> ./openssl.cnf.1
echo "dynamic_path = ${OPENSSL_INSTALLDIR}/lib/engines/lib${ENGINE_ID}.so" >> ./openssl.cnf.1
echo "engine_id = ${ENGINE_ID}" >> ./openssl.cnf.1

cp -f ./openssl.cnf.1 ${OPENSSL_INSTALLDIR}/openssl.cnf

echo "Installation of OpenSSL-${OPENSSL_VERSION} with ${ENGINE_ID} engine support to:"
echo "    ${OPENSSL_INSTALLDIR}"
echo "finished successfully."

