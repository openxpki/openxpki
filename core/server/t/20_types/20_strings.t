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
# AlphaPunct – word chars, dash, dot, colon, space (empty string allowed)

type_ok  'AlphaPunct', 'hello',           'plain word';
type_ok  'AlphaPunct', 'hello world',     'word with space';
type_ok  'AlphaPunct', 'foo-bar.baz:qux', 'dash, dot, colon';
type_ok  'AlphaPunct', '',               'empty string allowed';
type_ok  'AlphaPunct', 'realm_1.test',   'underscore (word char)';

type_nok 'AlphaPunct', 'foo@bar',        '@ sign';
type_nok 'AlphaPunct', 'hello/world',    'slash';
type_nok 'AlphaPunct', "tab\there",      'tab character';
type_nok 'AlphaPunct', undef,            'undef';

###########################################################################
# Ident – word chars + dash, one or more

type_ok  'Ident', 'my-ident',     'word with dash';
type_ok  'Ident', 'ABC',          'uppercase';
type_ok  'Ident', 'foo123',       'alphanumeric';
type_ok  'Ident', 'a',            'single char';

type_nok 'Ident', '',             'empty string rejected';
type_nok 'Ident', 'foo.bar',      'dot rejected';
type_nok 'Ident', 'foo bar',      'space rejected';
type_nok 'Ident', undef,          'undef';

###########################################################################
# Empty – only the empty string

type_ok  'Empty', '',             'empty string';
type_nok 'Empty', ' ',           'space rejected';
type_nok 'Empty', '0',           'zero char rejected';
type_nok 'Empty', undef,         'undef rejected';

done_testing;
