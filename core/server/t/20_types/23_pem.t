#!/usr/bin/perl
use strict;
use warnings;

use FindBin qw( $Bin );
use Test::More;
use lib "$Bin/../..";
use OpenXPKI::Types;

sub type_ok {
    my ($type_name, $val, $label) = @_;
    my $type = Moose::Util::TypeConstraints::find_type_constraint($type_name)
        or die "Unknown type: $type_name";
    ok $type->check($val), "$type_name: $label";
}

sub type_nok {
    my ($type_name, $val, $label) = @_;
    my $type = Moose::Util::TypeConstraints::find_type_constraint($type_name)
        or die "Unknown type: $type_name";
    ok !$type->check($val), "$type_name rejects: $label";
}

# Minimal structurally-valid PEM blocks (content validity not checked by types)
my $CERT = "-----BEGIN CERTIFICATE-----\nMIIBfakeCertData\n-----END CERTIFICATE-----\n";
my $TRUSTED_CERT = "-----BEGIN TRUSTED CERTIFICATE-----\nMIIBfakeCertData\n-----END TRUSTED CERTIFICATE-----\n";
my $CHAIN = $CERT . "-----BEGIN CERTIFICATE-----\nMIIBfakeIssuer\n-----END CERTIFICATE-----\n";
my $PKCS7 = "-----BEGIN PKCS7-----\nMIIBfakePkcs7Data\n-----END PKCS7-----\n";
my $PKEY = "-----BEGIN PRIVATE KEY-----\nMIIBfakePkeyData\n-----END PRIVATE KEY-----\n";
my $RSA_PKEY = "-----BEGIN RSA PRIVATE KEY-----\nMIIBfakePkeyData\n-----END RSA PRIVATE KEY-----\n";
my $ENC_PKEY = "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIBfakePkeyData\n-----END ENCRYPTED PRIVATE KEY-----\n";
my $PUBKEY = "-----BEGIN PUBLIC KEY-----\nMIIBfakePubkeyData\n-----END PUBLIC KEY-----\n";

###########################################################################
# PEM – base: valid base64 chars + PEM header chars

type_ok  'PEM', $CERT,          'certificate block';
type_ok  'PEM', $CHAIN,         'cert chain (multiple blocks)';
type_ok  'PEM', "MIIB\n",       'raw base64 with newline';
type_ok  'PEM', "AB12+/=\n",    'all valid PEM chars';

type_nok 'PEM', "hello_world\n", 'underscore not allowed in PEM';
type_nok 'PEM', "data\there\n",  'tab not allowed';
type_nok 'PEM', '',             'empty string';
type_nok 'PEM', undef,          'undef';

###########################################################################
# PEMCert

type_ok  'PEMCert', $CERT,          'standard BEGIN CERTIFICATE';
type_ok  'PEMCert', $TRUSTED_CERT,  'BEGIN TRUSTED CERTIFICATE';

type_nok 'PEMCert', $CHAIN,         'chain with multiple certs rejected';
type_nok 'PEMCert', $PKEY,          'private key rejected';
type_nok 'PEMCert', "MIIB\n",       'raw base64 rejected';
type_nok 'PEMCert', undef,          'undef';

###########################################################################
# PEMCertChain – one or more certificate blocks

type_ok  'PEMCertChain', $CERT,    'single cert';
type_ok  'PEMCertChain', $CHAIN,   'two-cert chain';
type_ok  'PEMCertChain', $TRUSTED_CERT, 'trusted cert';

type_nok 'PEMCertChain', $PKEY,   'private key rejected';
type_nok 'PEMCertChain', $PKCS7,  'PKCS7 rejected';
type_nok 'PEMCertChain', undef,   'undef';

###########################################################################
# PEMPKCS7

type_ok  'PEMPKCS7', $PKCS7,    'PKCS7 block';

type_nok 'PEMPKCS7', $CERT,     'certificate rejected';
type_nok 'PEMPKCS7', $PKEY,     'private key rejected';
type_nok 'PEMPKCS7', undef,     'undef';

###########################################################################
# PEMPKey – PKCS#8, PKCS#1, or encrypted private key

type_ok  'PEMPKey', $PKEY,      'PKCS#8 PRIVATE KEY';
type_ok  'PEMPKey', $RSA_PKEY,  'RSA PRIVATE KEY (PKCS#1)';
type_ok  'PEMPKey', $ENC_PKEY,  'ENCRYPTED PRIVATE KEY';

type_nok 'PEMPKey', $CERT,      'certificate rejected';
type_nok 'PEMPKey', $PUBKEY,    'public key rejected';
type_nok 'PEMPKey', undef,      'undef';

###########################################################################
# PEMPubKey

type_ok  'PEMPubKey', $PUBKEY,   'PUBLIC KEY block';

type_nok 'PEMPubKey', $PKEY,     'private key rejected';
type_nok 'PEMPubKey', $CERT,     'certificate rejected';
type_nok 'PEMPubKey', undef,     'undef';

done_testing;
