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

sub coerce_ok {
    my ($type_name, $val, $expected, $label) = @_;
    my $type = Moose::Util::TypeConstraints::find_type_constraint($type_name)
        or die "Unknown type: $type_name";
    is_deeply $type->coerce($val), $expected, "coerce $type_name: $label";
}

###########################################################################
# RDNAttribute – two-element ArrayRef [type, value]

type_ok  'RDNAttribute', ['CN', 'Test User'],         'named attribute CN';
type_ok  'RDNAttribute', ['organizationName', 'Acme'],'long attribute name';
type_ok  'RDNAttribute', ['2.5.4.3', 'Test'],         'OID as type';
type_ok  'RDNAttribute', ['OU', 'IT Department'],     'value with space';

type_nok 'RDNAttribute', ['CN'],                      'missing value (one element)';
type_nok 'RDNAttribute', ['CN', 'a', 'b'],            'too many elements';
type_nok 'RDNAttribute', ['-bad', 'value'],           'type starts with dash';
type_nok 'RDNAttribute', ['CN', "line1\nline2"],      'multiline value rejected';
type_nok 'RDNAttribute', 'CN=Test',                  'string instead of arrayref';
type_nok 'RDNAttribute', undef,                       'undef';

###########################################################################
# ParsedDN – three-level arrayref: RDN → attributes → [attr, val]

type_ok  'ParsedDN', [[['CN', 'Test']]], 'single RDN, single attr';
type_ok  'ParsedDN',
    [[['CN', 'Test']], [['O', 'Example']], [['C', 'DE']]],
    'three RDNs';
type_ok  'ParsedDN',
    [[['CN', 'Test'], ['emailAddress', 't@example.com']]],
    'multi-value RDN';

type_nok 'ParsedDN', [['CN', 'Test']],  'missing nesting level (2D instead of 3D)';
type_nok 'ParsedDN', 'CN=Test',         'string instead of arrayref';
type_ok  'ParsedDN', [],               'empty arrayref satisfies ArrayRef[...]';
type_nok 'ParsedDN', undef,            'undef';

# coercion from DN string
{
    my $type = Moose::Util::TypeConstraints::find_type_constraint('ParsedDN');
    my $result = $type->coerce('CN=Test User,O=Example');
    is ref($result), 'ARRAY', 'coerce from DN string returns arrayref';
    ok scalar(@$result) >= 2, 'at least two RDNs parsed';
    is ref($result->[0]), 'ARRAY', 'first RDN is arrayref';
    is ref($result->[0][0]), 'ARRAY', 'first attr is arrayref';
    is $result->[0][0][0], 'CN', 'first attr name is CN';
    is $result->[0][0][1], 'Test User', 'first attr value is Test User';
}

###########################################################################
# ArrayOrAlphaPunct – ArrayRef[AlphaPunct], coercible from single AlphaPunct

type_ok  'ArrayOrAlphaPunct', ['foo', 'bar'],      'array of two strings';
type_ok  'ArrayOrAlphaPunct', ['single'],          'single-element array';
type_nok 'ArrayOrAlphaPunct', 'foo',              'plain string not accepted without coerce';

coerce_ok 'ArrayOrAlphaPunct', 'hello', ['hello'], 'string coerced to single-element array';

###########################################################################
# ArrayRefOrStr – ArrayRef[Str], coercible from single Str

type_ok  'ArrayRefOrStr', ['foo', 'bar'],   'array of strings';
type_ok  'ArrayRefOrStr', ['a'],            'single-element array';
type_nok 'ArrayRefOrStr', 'foo',           'plain string not accepted without coerce';

coerce_ok 'ArrayRefOrStr', 'hello', ['hello'], 'string coerced to single-element array';

###########################################################################
# ArrayRefOrCommaList – coercible from comma-separated string

type_ok  'ArrayRefOrCommaList', ['a', 'b', 'c'], 'array of strings';

coerce_ok 'ArrayRefOrCommaList', 'a,b,c',    ['a', 'b', 'c'],  'comma list coerced';
coerce_ok 'ArrayRefOrCommaList', 'a, b, c',  ['a', 'b', 'c'],  'spaces trimmed';
coerce_ok 'ArrayRefOrCommaList', 'single',   ['single'],        'single value coerced';

###########################################################################
# ConfigPath – ArrayRef[Str], coercible from dot-separated string

type_ok  'ConfigPath', ['system', 'crypto', 'secret'], 'array path';

coerce_ok 'ConfigPath', 'system.crypto.secret', ['system', 'crypto', 'secret'], 'dot path coerced';
coerce_ok 'ConfigPath', 'single',               ['single'],                     'single component';

done_testing;
