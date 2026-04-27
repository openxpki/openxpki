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

type_ok  'DNSName', 'example.com',       'simple FQDN';
type_ok  'DNSName', 'sub.example.com',   'subdomain';
type_ok  'DNSName', '*.example.com',     'wildcard';
type_ok  'DNSName', 'hostname',          'single label (no dot)';
type_ok  'DNSName', 'a1-b2.example.com', 'alphanumeric with dash';

type_nok 'DNSName', '*.*.example.com', 'double wildcard';
type_nok 'DNSName', '-invalid.com',    'label starts with dash';
type_nok 'DNSName', 'invalid-.com',    'label ends with dash';
type_nok 'DNSName', '.example.com',    'leading dot';
type_nok 'DNSName', 'exam ple.com',    'space in label';
type_nok 'DNSName', '',                'empty string';
type_nok 'DNSName', undef,             'undef';

done_testing;
