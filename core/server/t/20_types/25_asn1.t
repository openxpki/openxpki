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
# GeneralName – any single-line string without control characters

type_ok  'GeneralName', 'example.com',           'domain name';
type_ok  'GeneralName', 'user@example.com',       'email address';
type_ok  'GeneralName', 'Hello, World!',          'text with punctuation';
type_ok  'GeneralName', '192.168.1.1',            'IPv4 address';
type_ok  'GeneralName', 'CN=Test, O=Example',     'DN string';
type_ok  'GeneralName', 'a',                      'single char';

type_nok 'GeneralName', "line1\nline2",           'newline (control char)';
type_nok 'GeneralName', "tab\there",              'tab (control char)';
type_nok 'GeneralName', "\x00null",               'null byte';
type_nok 'GeneralName', "\x7f",                  'DEL character';
type_nok 'GeneralName', '',                       'empty string';
type_nok 'GeneralName', undef,                    'undef';

###########################################################################
# PrintableString – ASN.1 subset: A-Za-z0-9 space '()+,-./:=?

type_ok  'PrintableString', 'Hello World',            'letters and space';
type_ok  'PrintableString', 'CN=Test User',           'equals sign';
type_ok  'PrintableString', 'O=Example Corp.',        'dot and equals';
type_ok  'PrintableString', "A-Za-z0-9 '()+,-./:=?", 'all allowed chars';
type_ok  'PrintableString', '',                       'empty string allowed';

type_nok 'PrintableString', 'user@example.com',      '@ not in PrintableString';
type_nok 'PrintableString', 'Stra\xdfe',             'non-ASCII';
type_nok 'PrintableString', "line\nnewline",         'newline not allowed';
type_nok 'PrintableString', 'foo&bar',               '& not allowed';
type_nok 'PrintableString', undef,                   'undef';

###########################################################################
# OID – dotted numeric (at least two components)

type_ok  'OID', '1.2.3',                  'three-component OID';
type_ok  'OID', '1.3.6.1.5.5.7.3.1',     'long OID (serverAuth)';
type_ok  'OID', '2.5.4.3',               'CN OID';
type_ok  'OID', '1.2',                   'minimal two-component OID';

type_nok 'OID', '1',                     'single component rejected';
type_nok 'OID', '1.2.3.a',              'non-numeric component';
type_nok 'OID', '.1.2.3',              'leading dot';
type_nok 'OID', '1.2.3.',              'trailing dot';
type_nok 'OID', '1.2..3',             'double dot';
type_nok 'OID', '',                    'empty string';
type_nok 'OID', undef,                 'undef';

done_testing;
