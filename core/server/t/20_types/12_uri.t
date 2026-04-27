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

type_ok  'URI', 'https://example.com',                'HTTPS URL';
type_ok  'URI', 'http://example.com/path?q=1&r=2',    'HTTP with query';
type_ok  'URI', 'ldap://ldap.example.com/dc=example', 'LDAP URI';
type_ok  'URI', 'urn:oid:1.2.3.4',                    'URN';
type_ok  'URI', 'ftp://ftp.example.com/file.tar.gz',  'FTP URI';
type_ok  'URI', 'http://user:pass@host/path#frag',     'URI with auth and fragment';
type_ok  'URI', 'http://',                             'slashes count as path component per regex';

type_nok 'URI', 'example.com',    'missing scheme';
type_nok 'URI', '://example.com', 'empty scheme';
type_nok 'URI', '',               'empty string';
type_nok 'URI', undef,            'undef';

done_testing;
