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
# Hex – must start with 0x followed by hex digits

type_ok  'Hex', '0xff',         'lowercase ff';
type_ok  'Hex', '0xFF',         'uppercase FF';
type_ok  'Hex', '0x0',          'zero';
type_ok  'Hex', '0xdeadbeef',   'longer hex';
type_ok  'Hex', '0xABCDEF',     'all hex letters uppercase';

type_nok 'Hex', 'ff',           'missing 0x prefix';
type_nok 'Hex', '0x',           '0x with no digits';
type_nok 'Hex', '0xgg',         'non-hex digit g';
type_nok 'Hex', '42',           'plain decimal';
type_nok 'Hex', '',             'empty string';
type_nok 'Hex', undef,          'undef';

###########################################################################
# IntOrHex – Int value; coerced from Hex

type_ok  'IntOrHex', '42',       'plain integer';
type_ok  'IntOrHex', '0',        'zero';
type_ok  'IntOrHex', '-5',       'negative integer';

type_nok 'IntOrHex', '0xff',     'hex string is not an Int (needs coerce)';
type_nok 'IntOrHex', '3.14',     'float rejected';
type_nok 'IntOrHex', 'abc',      'string rejected';

# coercion: Hex → Int
{
    my $type = Moose::Util::TypeConstraints::find_type_constraint('IntOrHex');
    my $result = $type->coerce('0xff');
    is $result, '255', 'coerce 0xff to 255';

    $result = $type->coerce('0x10');
    is $result, '16', 'coerce 0x10 to 16';

    $result = $type->coerce(99);
    is $result, 99, 'Int passes through coercion unchanged';
}

###########################################################################
# PosInt – integer strictly greater than zero

type_ok  'PosInt', 1,     'one';
type_ok  'PosInt', 42,    'positive number';
type_ok  'PosInt', 99999, 'large number';

type_nok 'PosInt', 0,     'zero rejected';
type_nok 'PosInt', -1,    'negative rejected';
type_ok  'PosInt', '1',   'Moose Int accepts string "1" (duck-typed)';
type_nok 'PosInt', undef, 'undef rejected';

done_testing;
