#!/bin/bash
#
# Create certificates and store them in $OXI_CONF/etc/openxpki/ssl/xxx/
# Import the certificates into MySQL using "openxpkiadm".
#
# This script assumes that there is a valid OpenXPKI configuration below
# $OXI_CONF so that "openxpkiadm" can run and access the database.
#
# Please note that the PKI realms used in this script must correspond to the
# ones found in $OXI_CONF/realms.yaml.
#

# Where to store the certificates
OXI_CONF="$1"
[ ! -z "$OXI_CONF" -a -d "$OXI_CONF" ] || ( echo "OpenXPKI test config directory must be specified as first parameter"; exit 1 )

# Only variable that is globally used
TEMPDIR=`mktemp -d`

# Exit handler
function _exit () {
    if [ $1 -ne 0 ]; then
        echo "ERROR - last command exited with code $1, output:" >&2 && cat $TEMPDIR/log >&2
    fi
    rm -Rf $TEMPDIR
    exit $1
}
trap '_exit $?' EXIT


write_openssl_config() {
    cat <<EOF > $TEMPDIR/openssl.cnf
    HOME            = .
    RANDFILE        = \$ENV::HOME/.rnd

    [ ca ]
    default_ca      = CA_default

    [ CA_default ]
    dir             = $TEMPDIR
    certs           = $TEMPDIR/certs
    crl_dir         = $TEMPDIR/crl
    database        = $TEMPDIR/index.txt
    new_certs_dir   = $TEMPDIR/
    serial          = $TEMPDIR/serial
    crlnumber       = $TEMPDIR/crlnumber

    crl             = $TEMPDIR/crl.pem
    private_key     = $TEMPDIR/cakey.pem
    RANDFILE        = $TEMPDIR/.rand

    default_md      = sha256
    preserve        = no
    policy          = policy_none
    default_days    = 365
    x509_extensions = usr_cert

    [policy_none]
    domainComponent        = optional
    organizationalUnitName = optional
    commonName             = supplied
    emailAddress           = optional

    [ req ]
    default_bits           = 2048
    distinguished_name     = req_distinguished_name
    x509_extensions        = v3_ca

    [ req_distinguished_name ]
    domainComponent        = Domain Component
    commonName             = Common Name

    [ usr_cert ]
    basicConstraints       = CA:FALSE
    subjectKeyIdentifier   = hash
    authorityKeyIdentifier = keyid,issuer

    [ vault_cert ]
    basicConstraints       = CA:FALSE
    subjectKeyIdentifier   = hash
    authorityKeyIdentifier = keyid:always,issuer
    keyUsage               = keyEncipherment
    extendedKeyUsage       = emailProtection

    [ v3_ca ]
    basicConstraints       = critical,CA:true
    subjectKeyIdentifier   = hash
    authorityKeyIdentifier = keyid:always,issuer
    keyUsage               = cRLSign, keyCertSign
EOF

    touch $TEMPDIR/index.txt
    touch $TEMPDIR/index.txt.attr
    echo 01 > $TEMPDIR/serial
    echo 00 > $TEMPDIR/crlnumber
}

# If SIGNER_NAMESTEM == "SELF" we assume the cert is self signed
issue_cert() {
    local ADD_PARAMS=$1
    local CERT_NAMESTEM=$2
    local LABEL=$3
    local SIGNER_NAMESTEM=$4
    local VALID_FROM=$5
    local VALID_TO=$6

    # Certificate Signing Request
    openssl req -config $TEMPDIR/openssl.cnf -batch \
        -verbose \
        -newkey rsa:2048 \
        -subj "$LABEL" \
        -keyout $CERT_NAMESTEM.pem -passout pass:root \
        -out    $CERT_NAMESTEM.csr \
        > $TEMPDIR/log 2>&1

    # Issuance of Certificate
    local signerRef="-keyfile $SIGNER_NAMESTEM.pem -cert $SIGNER_NAMESTEM.crt"
    [ $SIGNER_NAMESTEM == "SELF" ] && local signerRef="-keyfile $CERT_NAMESTEM.pem -selfsign"

    openssl ca -config $TEMPDIR/openssl.cnf -batch \
        $ADD_PARAMS \
        -in $CERT_NAMESTEM.csr \
        $signerRef -passin pass:root \
        -startdate $VALID_FROM -enddate $VALID_TO \
        -notext \
        -out $CERT_NAMESTEM.crt \
        > $TEMPDIR/log 2>&1
}

make_certs() {
    local TARGET_DIR=$1
    local REALM=$2
    local GENERATION=$3
    local VALID_FROM=$4
    local VALID_TO=$5
    local ORPHAN=$6

    local SUBJECT_BASE="/DC=ORG/DC=OpenXPKI/OU=ACME/CN=$(echo "$REALM" | tr [:lower:] [:upper:])"
    local BASEPATH="$TEMPDIR/$REALM"

    # Remove OpenSSL info of previous certs  (otherwise it mixes our generations)
    rm -f $TEMPDIR/index.txt*
    touch $TEMPDIR/index.txt
    touch $TEMPDIR/index.txt.attr

    echo "Certificates for CA $2 (generation $GENERATION)"

    echo " - creation using OpenSSL"
    # Self signed DataVault cert
    issue_cert "-extensions vault_cert" \
        $BASEPATH-datavault-$GENERATION "$SUBJECT_BASE DataVault" \
        SELF \
        $VALID_FROM $VALID_TO

    # Self signed Root CA cert
    issue_cert "-extensions v3_ca" \
        $BASEPATH-root-$GENERATION "$SUBJECT_BASE Root CA" \
        SELF \
        $VALID_FROM $VALID_TO

    # Signing CA cert (signed by Root CA)
    issue_cert "-extensions v3_ca" \
        $BASEPATH-signer-$GENERATION "$SUBJECT_BASE Signing CA" \
        $BASEPATH-root-$GENERATION \
        $VALID_FROM $VALID_TO

    # SCEP cert (signed by Root CA)
    issue_cert "" \
        $BASEPATH-scep-$GENERATION "$SUBJECT_BASE SCEP" \
        $BASEPATH-root-$GENERATION \
        $VALID_FROM $VALID_TO

    # Client cert #1 (signed by Signing CA)
    issue_cert "" \
        $BASEPATH-alice-$GENERATION "$SUBJECT_BASE Client Alice" \
        $BASEPATH-signer-$GENERATION $VALID_FROM $VALID_TO

    # Client cert #2 (signed by Signing CA)
    issue_cert "" \
        $BASEPATH-bob-$GENERATION "$SUBJECT_BASE Client Bob" \
        $BASEPATH-signer-$GENERATION $VALID_FROM $VALID_TO

    # PKCS7 for client alice
    openssl crl2pkcs7 -nocrl \
        -certfile $BASEPATH-root-$GENERATION.crt \
        -certfile $BASEPATH-signer-$GENERATION.crt \
        -certfile $BASEPATH-alice-$GENERATION.crt \
        -out      $BASEPATH-alice-$GENERATION.p7b > $TEMPDIR/log 2>&1

    echo " - import into OpenXPKI"

    local OXI_IMPORT="openxpkiadm certificate import --force-no-verify --gen $GENERATION --realm $REALM"
    if [ -z "$ORPHAN" ]; then
        $OXI_IMPORT --file $BASEPATH-root-$GENERATION.crt      --token root             > $TEMPDIR/log 2>&1
        $OXI_IMPORT --file $BASEPATH-signer-$GENERATION.crt    --token certsign         > $TEMPDIR/log 2>&1
        $OXI_IMPORT --file $BASEPATH-datavault-$GENERATION.crt --token datasafe         > $TEMPDIR/log 2>&1
        $OXI_IMPORT --file $BASEPATH-scep-$GENERATION.crt      --token scep             > $TEMPDIR/log 2>&1
        $OXI_IMPORT --file $BASEPATH-alice-$GENERATION.crt --alias "$REALM-alice-${GENERATION}" > $TEMPDIR/log 2>&1
        $OXI_IMPORT --file $BASEPATH-bob-$GENERATION.crt   --alias "$REALM-bob-${GENERATION}"   > $TEMPDIR/log 2>&1
    else
        $OXI_IMPORT --file $BASEPATH-bob-$GENERATION.crt   --alias "$REALM-bob-${GENERATION}" --force-no-chain  > $TEMPDIR/log 2>&1
    fi

    mkdir -p $TARGET_DIR/ssl/$REALM
    if [ -z "$ORPHAN" ]; then
        mv $BASEPATH*.crt $TARGET_DIR/ssl/$REALM || true
        mv $BASEPATH*.pem $TARGET_DIR/ssl/$REALM || true
        mv $BASEPATH*.p7b $TARGET_DIR/ssl/$REALM || true
    else
        mv $BASEPATH-bob-$GENERATION.* $TARGET_DIR/ssl/$REALM || true
    fi
}

set -e

write_openssl_config

# Needed for openxpkiadm to work
export OPENXPKI_CONF_PATH=$OXI_CONF/config.d

make_certs $OXI_CONF alpha 1 20060101000000Z 20070131235959Z
make_certs $OXI_CONF alpha 2 20070101000000Z 21000131235959Z
make_certs $OXI_CONF alpha 3 21000101000000Z 21050131235959Z

make_certs $OXI_CONF beta 1  20170101000000Z 21050131235959Z

make_certs $OXI_CONF gamma 1 20170101000000Z 21050131235959Z ORPHAN

rm -Rf $TEMPDIR

# openxpkiadm alias list --realm alpha
# openxpkiadm alias list --realm alpha
