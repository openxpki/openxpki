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

type_ok  'FQDN', 'example.com',           'two-label domain';
type_ok  'FQDN', 'sub.example.com',       'subdomain';
type_ok  'FQDN', 'a.b.c.d.example.com',   'deep subdomain';
type_ok  'FQDN', 'a1-b2.example.com',     'label with dash and digit';

type_nok 'FQDN', 'hostname',             'single label (no dot) rejected';
type_nok 'FQDN', '*.example.com',        'wildcard rejected';
type_nok 'FQDN', '-bad.example.com',     'label starts with dash';
type_nok 'FQDN', '.example.com',         'leading dot';
type_nok 'FQDN', 'exam ple.com',         'space in label';
type_nok 'FQDN', '',                     'empty string';
type_nok 'FQDN', undef,                  'undef';

done_testing;
