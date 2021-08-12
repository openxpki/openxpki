#!/bin/bash

echo "OpenXPKI: importing test certificates"

CERT_DIR="$(dirname $0)/certificates"

openxpkiadm certificate import --file "$CERT_DIR/OpenXPKI_Root_CA.crt" > /dev/null

openxpkiadm alias --realm democa \
    --token datasafe \
    --file "$CERT_DIR/OpenXPKI_DataVault.crt" \
    --key  "$CERT_DIR/OpenXPKI_DataVault.key" \
    > /dev/null

sleep 1;

openxpkiadm alias --realm democa \
    --token certsign \
    --file "$CERT_DIR/OpenXPKI_Issuing_CA.crt" \
    --key  "$CERT_DIR/OpenXPKI_Issuing_CA.key" \
    > /dev/null

openxpkiadm alias --realm democa \
    --token scep \
    --file "$CERT_DIR/OpenXPKI_SCEP_RA.crt" \
    --key  "$CERT_DIR/OpenXPKI_SCEP_RA.key" \
    > /dev/null
