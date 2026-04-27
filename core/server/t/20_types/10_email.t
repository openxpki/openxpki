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

type_ok  'Email', 'user@example.com',          'simple address';
type_ok  'Email', 'user+tag@example.com',       'plus-tagged address';
type_ok  'Email', 'first.last@sub.example.org', 'dotted local part, subdomain';
type_ok  'Email', 'user@xn--nxasmq6b.com',     'punycode domain';

type_nok 'Email', 'notanemail',                 'no @ sign';
type_nok 'Email', '@example.com',               'empty local part';
type_nok 'Email', 'user@',                      'empty domain';
type_nok 'Email', 'user@.com',                  'domain starts with dot';
type_nok 'Email', '',                           'empty string';
type_nok 'Email', undef,                        'undef';

done_testing;
