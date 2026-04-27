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

###########################################################################
# TokenType

for my $v (qw( certsign crlsign datasafe scep cmcra )) {
    type_ok 'TokenType', $v, $v;
}
type_nok 'TokenType', 'unknown',  'arbitrary string';
type_nok 'TokenType', 'CERTSIGN', 'case-sensitive';
type_nok 'TokenType', '',         'empty string';
type_nok 'TokenType', undef,      'undef';

###########################################################################
# CertStatus

for my $v (qw( ISSUED REVOKED CRL_ISSUANCE_PENDING REVOKED_OR_PENDING UPCOMING VALID EXPIRED )) {
    type_ok 'CertStatus', $v, $v;
}
type_nok 'CertStatus', 'issued',   'lowercase rejected';
type_nok 'CertStatus', 'UNKNOWN',  'unknown value';
type_nok 'CertStatus', undef,      'undef';

###########################################################################
# SerializationFormat

type_ok  'SerializationFormat', 'simple', 'simple';
type_nok 'SerializationFormat', 'json',   'json not valid';
type_nok 'SerializationFormat', '',       'empty string';
type_nok 'SerializationFormat', undef,    'undef';

###########################################################################
# SANType

for my $v (qw( DNS email IP URI dirName RID otherName )) {
    type_ok 'SANType', $v, $v;
}
type_nok 'SANType', 'dns',     'lowercase rejected';
type_nok 'SANType', 'unknown', 'unknown value';
type_nok 'SANType', undef,     'undef';

###########################################################################
# KeyUsageBit

for my $v (qw( digitalSignature nonRepudiation keyEncipherment dataEncipherment
               keyAgreement keyCertSign cRLSign encipherOnly decipherOnly )) {
    type_ok 'KeyUsageBit', $v, $v;
}
type_nok 'KeyUsageBit', 'DigitalSignature', 'wrong case';
type_nok 'KeyUsageBit', 'sign',             'partial name';
type_nok 'KeyUsageBit', undef,              'undef';

###########################################################################
# ExtKeyUsageBit

for my $v (qw( clientAuth serverAuth emailProtection codeSigning timeStamping OCSPSigning )) {
    type_ok 'ExtKeyUsageBit', $v, $v;
}
type_nok 'ExtKeyUsageBit', 'ClientAuth', 'wrong case';
type_nok 'ExtKeyUsageBit', 'unknown',    'unknown value';
type_nok 'ExtKeyUsageBit', undef,        'undef';

###########################################################################
# CopyExtensions

for my $v (qw( none copy copyall )) {
    type_ok 'CopyExtensions', $v, $v;
}
type_nok 'CopyExtensions', 'all',  'not a valid value';
type_nok 'CopyExtensions', 'NONE', 'wrong case';
type_nok 'CopyExtensions', undef,  'undef';

###########################################################################
# ExtKeyUsageValue – named bit or numeric OID

type_ok  'ExtKeyUsageValue', 'clientAuth',          'named EKU bit';
type_ok  'ExtKeyUsageValue', 'OCSPSigning',          'named EKU bit';
type_ok  'ExtKeyUsageValue', '1.3.6.1.5.5.7.3.1',  'numeric OID (serverAuth)';
type_ok  'ExtKeyUsageValue', '2.16.840.1.101.3.4',  'numeric OID (AES)';

type_nok 'ExtKeyUsageValue', 'unknown',             'unknown named value';
type_nok 'ExtKeyUsageValue', '1',                   'single number (not an OID)';
type_nok 'ExtKeyUsageValue', 'clientauth',           'wrong case';
type_nok 'ExtKeyUsageValue', '',                    'empty string';
type_nok 'ExtKeyUsageValue', undef,                 'undef';

done_testing;
