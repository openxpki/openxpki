#!/bin/bash

# Debug='true'
# MyPerl='true'
[ "$MyPerl" = ' true' ] && [ -d /opt/myperl/bin ] && export PATH=/opt/myperl/bin:$PATH

#
# basic openxpki settings
#
BASE='/etc/openxpki';
OPENXPKI_CONFIG="${BASE}/config.d/system/server.yaml"
if [ -f "${OPENXPKI_CONFIG}" ]
then
   eval `egrep '^user:|^group:' "${OPENXPKI_CONFIG}" | sed -e 's/:  */=/g'`
else
   echo "ERROR: It seems that openXPKI is not installed at the default location (${BASE})!" >&2
   echo "Please install openXPKI or set BASE to the new PATH!" >&2
   exit 1
fi

REALM='ca-one'
# For automated testing we want to have this set to root
# unset this to get random passwords (put into the .pass files)
KEY_PASSWORD="root"
SSL_REALM="${BASE}/ca/${REALM}"

make_password() {

    PASSWORD_FILE=$1;
    touch "${PASSWORD_FILE}"
    chown $user:root "${PASSWORD_FILE}"
    chmod 640 "${PASSWORD_FILE}"
    if [ -z "$KEY_PASSWORD" ]; then
        dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 >"${PASSWORD_FILE}"
    else
        echo -n "$KEY_PASSWORD" > "${PASSWORD_FILE}"
    fi;

}

#
# CA and certificate settings
#
REQUEST_SUFFIX='csr'
KEY_SUFFIX='key'
CERTIFICATE_SUFFIX='crt'
REVOCATION_SUFFIX='crl'
PASS_SUFFIX='pass'
BACKUP_SUFFIX='~'

# root CA selfsigned (in production use company's root certificate)
ROOT_CA='OpenXPKI_CA-One_Root_CA'
ROOT_CA_REQUEST="${SSL_REALM}/${ROOT_CA}.${REQUEST_SUFFIX}"
ROOT_CA_KEY="${SSL_REALM}/${ROOT_CA}.${KEY_SUFFIX}"
ROOT_CA_KEY_PASSWORD="${SSL_REALM}/${ROOT_CA}.${PASS_SUFFIX}"
ROOT_CA_CERTIFICATE="${SSL_REALM}/${ROOT_CA}.${CERTIFICATE_SUFFIX}"
ROOT_CA_SUBJECT='/CN=OpenXPKI CA-One Root CA 1'
ROOT_CA_SERVER_FQDN='rootca.openxpki.net'

# issuing CA signed by root CA above
ISSUING_CA='OpenXPKI_CA-One_Issuing_CA'
ISSUING_CA_REQUEST="${SSL_REALM}/${ISSUING_CA}.${REQUEST_SUFFIX}"
ISSUING_CA_KEY="${SSL_REALM}/${ISSUING_CA}.${KEY_SUFFIX}"
ISSUING_CA_KEY_PASSWORD="${SSL_REALM}/${ISSUING_CA}.${PASS_SUFFIX}"
ISSUING_CA_CERTIFICATE="${SSL_REALM}/${ISSUING_CA}.${CERTIFICATE_SUFFIX}"
ISSUING_CA_SUBJECT='/DC=net/DC=openxpki/DC=ca-one/CN=OpenXPKI Issuing CA 1'

# SCEP registration authority certificate signed by root CA above
SCEP='OpenXPKI_CA-One_SCEP_RA'
SCEP_REQUEST="${SSL_REALM}/${SCEP}.${REQUEST_SUFFIX}"
SCEP_KEY="${SSL_REALM}/${SCEP}.${KEY_SUFFIX}"
SCEP_KEY_PASSWORD="${SSL_REALM}/${SCEP}.${PASS_SUFFIX}"
SCEP_CERTIFICATE="${SSL_REALM}/${SCEP}.${CERTIFICATE_SUFFIX}"
SCEP_SUBJECT='/DC=net/DC=openxpki/DC=ca-one/CN=OpenXPKI CA-One SCEP RA 1'

# Apache WEB certificate signed by root CA above
WEB='OpenXPKI_CA-One_Web_CA'
WEB_REQUEST="${SSL_REALM}/${WEB}.${REQUEST_SUFFIX}"
WEB_KEY="${SSL_REALM}/${WEB}.${KEY_SUFFIX}"
WEB_KEY_PASSWORD="${SSL_REALM}/${WEB}.${PASS_SUFFIX}"
WEB_CERTIFICATE="${SSL_REALM}/${WEB}.${CERTIFICATE_SUFFIX}"
WEB_SUBJECT='/DC=net/DC=openxpki/DC=ca-one/CN=issuing.ca-one.openxpki.net'
WEB_SERVER_FQDN='issuing.ca-one.openxpki.net'

# data vault certificate selfsigned
DATAVAULT='OpenXPKI_CA-One_DataVault'
DATAVAULT_REQUEST="${SSL_REALM}/${DATAVAULT}.${REQUEST_SUFFIX}"
DATAVAULT_KEY="${SSL_REALM}/${DATAVAULT}.${KEY_SUFFIX}"
DATAVAULT_KEY_PASSWORD="${SSL_REALM}/${DATAVAULT}.${PASS_SUFFIX}"
DATAVAULT_CERTIFICATE="${SSL_REALM}/${DATAVAULT}.${CERTIFICATE_SUFFIX}"
DATAVAULT_SUBJECT='/DC=net/DC=openxpki/DC=ca-one/DC=OpenXPKI Internal/CN=OpenXPKI CA-One DataVault'

#
# openssl.conf
#
BITS=4096
DAYS=371 # 2 years (default value not used for further enhancements)
RDAYS="3655" # 10 years for root
IDAYS="1828" # 5 years for issuing
SDAYS="$IDAYS" # 5 years for scep (same as issuing)
WDAYS="1096" # 3 years web
DDAYS="$RDAYS" # 10 years datavault (same a root)

# used by v3 extension for issuing ca certificate
ROOT_CA_HTTP_URI="URI:http://${ROOT_CA_SERVER_FQDN}/CertEnroll"
ROOT_CA_CERTIFICATE_STRING="OpenXPKI_CA-One_Root_CA"
ROOT_CA_CERTIFICATE_URI="${ROOT_CA_HTTP_URI}/${ROOT_CA_CERTIFICATE_STRING}.${CERTIFICATE_SUFFIX}"
ROOT_CA_REVOCATION_URI="${ROOT_CA_HTTP_URI}/${ROOT_CA_CERTIFICATE_STRING}.${REVOCATION_SUFFIX}"

# used by v3 extension for web certificate
ISSUING_HTTP_URI="URI:http://${WEB_SERVER_FQDN}/CertEnroll"
ISSUING_CERTIFICATE_URI="${ISSUING_HTTP_URI}/${ISSUING_CA}.${CERTIFICATE_SUFFIX}"
ISSUING_REVOCATION_URI="${ISSUING_HTTP_URI}/${ISSUING_CA}.${REVOCATION_SUFFIX}"

# creation neccessary directories and files
echo -n "creating configuration for openssl ($OPENSSL_CONF) .. "
test -d "${SSL_REALM}" || mkdir -m 750 -p "${SSL_REALM}" && chown ${user}:root "${SSL_REALM}"
OPENSSL_DIR="${SSL_REALM}/.openssl"
test -d "${OPENSSL_DIR}" || mkdir -m 700 "${OPENSSL_DIR}" && chown root:root "${OPENSSL_DIR}"
cd "${OPENSSL_DIR}";

OPENSSL_CONF="${OPENSSL_DIR}/openssl.cnf"

touch "${OPENSSL_DIR}/index.txt"
touch "${OPENSSL_DIR}/index.txt.attr"
echo 01 > "${OPENSSL_DIR}/serial"
echo 00 > "${OPENSSL_DIR}/crlnumber"

echo "
HOME			= .
RANDFILE		= \$ENV::HOME/.rnd

[ ca ]
default_ca		= CA_default

[ CA_default ]
dir			= ${OPENSSL_DIR}
certs			= ${OPENSSL_DIR}/certs
crl_dir			= ${OPENSSL_DIR}/
database		= ${OPENSSL_DIR}/index.txt
new_certs_dir		= ${OPENSSL_DIR}/
serial			= ${OPENSSL_DIR}/serial
crlnumber		= ${OPENSSL_DIR}/crlnumber

crl			= ${OPENSSL_DIR}/crl.pem
private_key		= ${OPENSSL_DIR}/cakey.pem
RANDFILE		= ${OPENSSL_DIR}/.rand

default_md		= sha256
preserve		= no
policy			= policy_none
default_days		= ${DAYS}

# x509_extensions               = v3_ca_extensions
# x509_extensions               = v3_issuing_extensions
# x509_extensions               = v3_datavault_extensions
# x509_extensions               = v3_scep_extensions
# x509_extensions               = v3_web_extensions

[policy_none]
domainComponent		= optional
organizationalUnitName	= optional
commonName		= supplied

[ req ]
default_bits		= ${BITS}
distinguished_name	= req_distinguished_name

# x509_extensions               = v3_ca_reqexts # not for root self signed, only for issuing
## x509_extensions              = v3_datavault_reqexts # not required self signed
# x509_extensions               = v3_scep_reqexts
# x509_extensions               = v3_web_reqexts

[ req_distinguished_name ]
domainComponent		= Domain Component
commonName		= Common Name

[ v3_ca_reqexts ]
subjectKeyIdentifier    = hash
keyUsage                = digitalSignature, keyCertSign, cRLSign

[ v3_datavault_reqexts ]
subjectKeyIdentifier    = hash
keyUsage                = keyEncipherment
extendedKeyUsage        = emailProtection

[ v3_scep_reqexts ]
subjectKeyIdentifier    = hash

[ v3_web_reqexts ]
subjectKeyIdentifier    = hash
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth, clientAuth


[ v3_ca_extensions ]
subjectKeyIdentifier    = hash
keyUsage                = digitalSignature, keyCertSign, cRLSign
basicConstraints        = critical,CA:TRUE
authorityKeyIdentifier  = keyid:always,issuer

[ v3_issuing_extensions ]
subjectKeyIdentifier    = hash
keyUsage                = digitalSignature, keyCertSign, cRLSign
basicConstraints        = critical,CA:TRUE
authorityKeyIdentifier  = keyid:always,issuer:always
crlDistributionPoints	= ${ROOT_CA_REVOCATION_URI}
authorityInfoAccess	= caIssuers;${ROOT_CA_CERTIFICATE_URI}

[ v3_datavault_extensions ]
subjectKeyIdentifier    = hash
keyUsage                = keyEncipherment
extendedKeyUsage        = emailProtection
basicConstraints        = CA:FALSE
authorityKeyIdentifier  = keyid:always,issuer

[ v3_scep_extensions ]
subjectKeyIdentifier    = hash
basicConstraints        = CA:FALSE
authorityKeyIdentifier  = keyid,issuer

[ v3_web_extensions ]
subjectKeyIdentifier    = hash
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth, clientAuth
basicConstraints        = critical,CA:FALSE
subjectAltName		= DNS:${WEB_SERVER_FQDN}
crlDistributionPoints	= ${ISSUING_REVOCATION_URI}
authorityInfoAccess	= caIssuers;${ISSUING_CERTIFICATE_URI}
" > "${OPENSSL_CONF}"

echo "done."

[ "$Debug" = 'true' ] || exec 2>/dev/null

echo "Creating certificates .. "

# self signed root
if [ ! -e "${ROOT_CA_CERTIFICATE}" ]
then
   echo "Did not find a root ca certificate file."
   echo -n "Creating an own self signed root ca .. "
   test -f "${ROOT_CA_KEY}" && \
    mv "${ROOT_CA_KEY}" "${ROOT_CA_KEY}${BACKUP_SUFFIX}"
   test -f "${ROOT_CA_KEY_PASSWORD}" && \
    mv "${ROOT_CA_KEY_PASSWORD}" "${ROOT_CA_KEY_PASSWORD}${BACKUP_SUFFIX}"
   make_password "${ROOT_CA_KEY_PASSWORD}"
   openssl req -verbose -config "${OPENSSL_CONF}" -extensions v3_ca_extensions -batch -x509 -newkey rsa:$BITS -days ${RDAYS} -passout file:"${ROOT_CA_KEY_PASSWORD}" -keyout "${ROOT_CA_KEY}" -subj "${ROOT_CA_SUBJECT}" -out "${ROOT_CA_CERTIFICATE}"
   echo "done."
fi

# signing certificate (issuing)
if [ ! -e "${ISSUING_CA_KEY}" ]
then
   echo "Did not find existing issuing CA key file."
   echo -n "Creating an issuing CA request .. "
   test -f "${ISSUING_CA_REQUEST}" && \
    mv "${ISSUING_CA_REQUEST}" "${ISSUING_CA_REQUEST}${BACKUP_SUFFIX}"
   make_password "${ISSUING_CA_KEY_PASSWORD}"
   openssl req -verbose -config "${OPENSSL_CONF}" -reqexts v3_ca_reqexts -batch -newkey rsa:$BITS -passout file:"${ISSUING_CA_KEY_PASSWORD}" -keyout "${ISSUING_CA_KEY}" -subj "${ISSUING_CA_SUBJECT}" -out "${ISSUING_CA_REQUEST}"
   echo "done."
   if [ -e "${ROOT_CA_KEY}" ]
   then
      echo -n "Signing issuing certificate with own root CA .. "
      test -f "${ISSUING_CA_CERTIFICATE}" && \
       mv "${ISSUING_CA_CERTIFICATE}" "${ISSUING_CA_CERTIFICATE}${BACKUP_SUFFIX}"
      openssl ca -config "${OPENSSL_CONF}" -extensions v3_issuing_extensions -batch -days ${IDAYS} -in "${ISSUING_CA_REQUEST}" -cert "${ROOT_CA_CERTIFICATE}" -passin file:"${ROOT_CA_KEY_PASSWORD}" -keyfile "${ROOT_CA_KEY}" -out "${ISSUING_CA_CERTIFICATE}"
      echo "done."
   else
      echo "No '${ROOT_CA_KEY}' key file!"
      echo "please sign generated request with the company's root CA key"
      exit 0
   fi
else
   if [ ! -e "${ISSUING_CA_CERTIFICATE}" ]
   then
      echo "No '${ISSUING_CA_CERTIFICATE}' certificate file!"
      if [ ! -e "${ROOT_CA_KEY}" ]
      then
         echo "No '${ROOT_CA_KEY}' key file!"
         echo "please sign generated request with the company's root CA key"
         exit 0
      else
         echo -n "Signing issuing certificate with own root CA .. "
         openssl ca -config "${OPENSSL_CONF}" -extensions v3_issuing_extensions -batch -days ${IDAYS} -in "${ISSUING_CA_REQUEST}" -cert "${ROOT_CA_CERTIFICATE}" -passin file:"${ROOT_CA_KEY_PASSWORD}" -keyfile "${ROOT_CA_KEY}" -out "${ISSUING_CA_CERTIFICATE}"
         echo "done."
      fi
   fi
fi

# Data Vault is only used internally, use self signed
if [ ! -e "${DATAVAULT_KEY}" ]
then
   echo "Did not find existing DataVault certificate file."
   echo -n "Creating a self signed DataVault certificate .. "
   test -f "${DATAVAULT_CERTIFICATE}" && \
    mv "${DATAVAULT_CERTIFICATE}" "${DATAVAULT_CERTIFICATE}${BACKUP_SUFFIX}"
   make_password "${DATAVAULT_KEY_PASSWORD}"
   openssl req -verbose -config "${OPENSSL_CONF}" -extensions v3_datavault_extensions -batch -x509 -newkey rsa:$BITS -days ${DDAYS} -passout file:"${DATAVAULT_KEY_PASSWORD}" -keyout "${DATAVAULT_KEY}" -subj "${DATAVAULT_SUBJECT}" -out "${DATAVAULT_CERTIFICATE}"
   echo "done."
fi

# scep certificate
if [ ! -e "${SCEP_KEY}" ]
then
   echo "Did not find existing SCEP certificate file."
   echo -n "Creating a SCEP request .. "
   test -f "${SCEP_REQUEST}" && \
    mv "${SCEP_REQUEST}" "${SCEP_REQUEST}${BACKUP_SUFFIX}"
   make_password "${SCEP_KEY_PASSWORD}"
   openssl req -verbose -config "${OPENSSL_CONF}" -reqexts v3_scep_reqexts -batch -newkey rsa:$BITS -passout file:"${SCEP_KEY_PASSWORD}" -keyout "${SCEP_KEY}" -subj "${SCEP_SUBJECT}" -out "${SCEP_REQUEST}"
   echo "done."
   echo -n "Signing SCEP certificate with Issuing CA .. "
   test -f "${SCEP_CERTIFICATE}" && \
    mv "${SCEP_CERTIFICATE}" "${SCEP_CERTIFICATE}${BACKUP_SUFFIX}"
   openssl ca -config "${OPENSSL_CONF}" -extensions v3_scep_extensions -batch -days ${SDAYS} -in "${SCEP_REQUEST}" -cert "${ISSUING_CA_CERTIFICATE}" -passin file:"${ISSUING_CA_KEY_PASSWORD}" -keyfile "${ISSUING_CA_KEY}" -out "${SCEP_CERTIFICATE}"
   echo "done."
fi

# web certificate
if [ ! -e "${WEB_KEY}" ]
then
   echo "Did not find existing WEB certificate file."
   echo -n "Creating a Web request .. "
   test -f "${WEB_REQUEST}" && \
    mv "${WEB_REQUEST}" "${WEB_REQUEST}${BACKUP_SUFFIX}"
   make_password "${WEB_KEY_PASSWORD}"
   openssl req -verbose -config "${OPENSSL_CONF}" -reqexts v3_web_reqexts -batch -newkey rsa:$BITS -passout file:"${WEB_KEY_PASSWORD}" -keyout "${WEB_KEY}" -subj "${WEB_SUBJECT}" -out "${WEB_REQUEST}"
   echo "done."
   echo -n "Signing Web certificate with Issuing CA .. "
   test -f "${WEB_CERTIFICATE}" && \
    mv "${WEB_CERTIFICATE}" "${WEB_CERTIFICATE}${BACKUP_SUFFIX}"
   openssl ca -config "${OPENSSL_CONF}" -extensions v3_web_extensions -batch -days ${WDAYS} -in "${WEB_REQUEST}" -cert "${ISSUING_CA_CERTIFICATE}" -passin file:"${ISSUING_CA_KEY_PASSWORD}" -keyfile "${ISSUING_CA_KEY}" -out "${WEB_CERTIFICATE}"
   echo "done."
fi

cd $OLDPWD;
# rm $TMP/*;
# rmdir $TMP;

# chown/chmod
chmod 400 ${SSL_REALM}/*.${PASS_SUFFIX}
chmod 440 ${SSL_REALM}/*.${KEY_SUFFIX}
chmod 444 ${SSL_REALM}/*.${CERTIFICATE_SUFFIX}
chown root:root ${SSL_REALM}/*.${REQUEST_SUFFIX} ${SSL_REALM}/*.${KEY_SUFFIX} ${SSL_REALM}/*.${PASS_SUFFIX}
chown root:${group} ${SSL_REALM}/*.${CERTIFICATE_SUFFIX} ${SSL_REALM}/*.${KEY_SUFFIX}

echo -n "Starting import ... "
echo "done."
echo ""

openxpkiadm certificate import --file "${ROOT_CA_CERTIFICATE}"
openxpkiadm certificate import --file "${ISSUING_CA_CERTIFICATE}" --realm "${REALM}" --token certsign
openxpkiadm certificate import --file "${SCEP_CERTIFICATE}" --realm "${REALM}" --token scep
openxpkiadm certificate import --file "${DATAVAULT_CERTIFICATE}" --realm "${REALM}" --token datasafe

# Create symlinks for the aliases used by the default config
ln -s "${ISSUING_CA_KEY}" "${SSL_REALM}/ca-signer-1.pem"
ln -s "${SCEP_KEY}" "${SSL_REALM}/scep-1.pem"
ln -s "${DATAVAULT_KEY}" "${SSL_REALM}/vault-1.pem"

echo "Place web certificate, private key, ... in web server configuration to enable ssl on openxpki web pages!"
echo ""
echo "OpenXPKI configuration should be done now, 'openxpkictl start' to fire up server'"
echo ""
echo "Thanks for using OpenXPKI - Have a nice day ;)"
echo ""
