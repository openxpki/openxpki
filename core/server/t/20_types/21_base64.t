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

# standard base64
type_ok  'Base64', 'SGVsbG8gV29ybGQ=',   'standard base64 with padding';
type_ok  'Base64', 'AAAA',               'all same chars';
type_ok  'Base64', 'aB3+/=',            'standard base64 special chars';
# URL-safe base64
type_ok  'Base64', 'aB3-_',             'URL-safe base64 (dash, underscore)';
# mixed
type_ok  'Base64', 'abc123DEF',         'alphanumeric only';

type_ok  'Base64', 'hello world',       'space IS allowed (space is literal inside char class with /x)';
type_nok 'Base64', 'foo@bar',           '@ not allowed';
type_nok 'Base64', "line1\nline2",      'newline not allowed';
type_nok 'Base64', '',                  'empty string';
type_nok 'Base64', undef,              'undef';

done_testing;
