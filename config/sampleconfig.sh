#!/bin/bash

BASE="/etc/openxpki/ssl/ca-one/";
PATH=/opt/myperl/bin:$PATH
export PATH

if [ ! -d "$BASE" ]; then 
    mkdir -p "$BASE";
fi

if [ -e "$BASE/ca-root-1.crt" ] ||  [ -e "$BASE/ca-root-1.pem" ]; then
   echo "found exisiting ca files in directory, please remove all files!"
   exit 1;
fi

TMP=`mktemp -d`
OLDPWD=`pwd`;

cd "$TMP";

(
cat <<EOF
HOME			= .
RANDFILE		= \$ENV::HOME/.rnd
[ ca ]
default_ca	= CA_default

[ CA_default ]
dir		= .	
certs		= ./certs
crl_dir		= ./crl	
database	= ./index.txt
new_certs_dir	= ./	
serial		= ./serial
crlnumber	= ./crlnumber	
				
crl		= ./crl.pem 	
private_key	= ./cakey.pem	
RANDFILE	= ./.rand	

default_md      = sha1       
preserve        = no   
policy          = policy_none
default_days    = 365
x509_extensions	= usr_cert	

[policy_none]
domainComponent = optional
organizationalUnitName = optional
commonName = supplied

[ req ]
default_bits		= 2048 
distinguished_name      = req_distinguished_name
x509_extensions = v3_ca 

[ req_distinguished_name ]
domainComponent = Domain Component
commonName = Common Name

[ usr_cert ]

basicConstraints=CA:FALSE
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer

[ vault_cert ]
basicConstraints=CA:FALSE
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
keyUsage = keyEncipherment
extendedKeyUsage=emailProtection

[ v3_ca ]

subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = critical,CA:true
keyUsage = cRLSign, keyCertSign
EOF
)  > openssl.cnf 

touch index.txt
touch index.txt.attr
echo 01 > serial
echo 00 > crlnumber


echo "Creating certificates"

exec 2>/dev/null

openssl req -verbose -config openssl.cnf  -x509 -newkey rsa:2048 -keyout "$BASE/ca-root-1.pem" -out "$BASE/ca-root-1.crt" -days 1826 -subj "/DC=ORG/DC=OpenXPKI/OU=Test CA/CN=Root CA" -batch -passout pass:root
 
openssl req -verbose  -config openssl.cnf -newkey rsa:2048 -keyout "$BASE/ca-one-signer-1.pem" -out csr.pem -batch -passout pass:root -subj "/DC=ORG/DC=OpenXPKI/OU=Test CA/CN=CA ONE"
 
openssl ca -in csr.pem  -config openssl.cnf -keyfile "$BASE/ca-root-1.pem" -cert "$BASE/ca-root-1.crt" -out "$BASE/ca-one-signer-1.crt"  -batch -passin pass:root  -extensions v3_ca -days 1095 -outdir .
 
# Data Vault is only used internally, use self signed
openssl req -verbose -config openssl.cnf -newkey rsa:2048 -keyout "$BASE/ca-one-vault-1.pem" -out "$BASE/ca-one-vault-1.crt" -batch -passout pass:root -x509 -days 365 -extensions vault_cert -subj "/DC=OpenXPKI Internal/CN=DataVault"
 
openssl req -verbose  -config openssl.cnf -newkey rsa:2048 -keyout "$BASE/ca-one-scep-1.pem" -out csr.pem -batch -passout pass:root  -subj "/DC=ORG/DC=OpenXPKI/OU=Test CA/CN=SCEP"
 
openssl ca -in csr.pem  -config openssl.cnf -keyfile "$BASE/ca-root-1.pem" -cert "$BASE/ca-root-1.crt" -out "$BASE/ca-one-scep-1.crt" -batch -passin pass:root -outdir .

cd $OLDPWD;
rm $TMP/*;
rmdir $TMP;

# chown/chmod 

chown openxpki:root $BASE/*;
chmod 400 $BASE/*.pem;
chmod 444 $BASE/*.crt;

echo "Starting import";

openxpkiadm certificate import  --file $BASE/ca-root-1.crt
openxpkiadm certificate import --file $BASE/ca-one-signer-1.crt --realm ca-one --token certsign
openxpkiadm certificate import --file $BASE/ca-one-vault-1.crt --realm ca-one --token datasafe
openxpkiadm certificate import --file $BASE/ca-one-scep-1.crt --realm ca-one --token scep

echo "Configuration should be done now, 'openxpkictl start' to fire up server'"
echo ""
echo "Thanks for using OpenXPKI - Have a nice day ;)"
echo ""

