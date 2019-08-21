#!/bin/bash

echo "OpenXPKI: importing test certificates"

#
# Files for /etc
#
BASE="/etc/openxpki/ca";
DEMOCA="$BASE/democa"
if [ ! -d "$DEMOCA" ]; then mkdir -p "$DEMOCA"; fi

if [ -e "$DEMOCA/ca-root-1.crt" ] ||  [ -e "$DEMOCA/ca-root-1.pem" ]; then
   echo "Found exisiting ca files in directory, please remove all files!"
   exit 1
fi

cp -r $(dirname $0)/certificates/* $BASE/

#
# Database entries
#
openxpkiadm certificate import --file "$DEMOCA/ca-root-1.crt" > /dev/null
openxpkiadm certificate import --realm democa --file "$DEMOCA/ca-signer-1.crt" --token certsign > /dev/null
openxpkiadm certificate import --realm democa --file "$DEMOCA/scep-1.crt" --token scep > /dev/null
openxpkiadm certificate import --realm democa --file "$BASE/vault-1.crt" --token datasafe > /dev/null
