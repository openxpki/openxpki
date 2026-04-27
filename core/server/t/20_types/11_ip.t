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
# IP (any)

type_ok  'IP', '192.168.1.1',   'IPv4';
type_ok  'IP', '10.0.0.0',      'IPv4 network address';
type_ok  'IP', '::1',           'IPv6 loopback';
type_ok  'IP', '2001:db8::1',   'IPv6 abbreviated';
type_ok  'IP', '::ffff:192.0.0.1', 'Mixed notation';

type_nok 'IP', 'fe80::1%eth0',  'IPv6 link-local with zone id (zone IDs not supported)';
type_nok 'IP', '999.0.0.1',     'IPv4 octet out of range';
type_nok 'IP', 'not-an-ip',     'arbitrary string';
type_nok 'IP', '',              'empty string';
type_nok 'IP', undef,           'undef';

###########################################################################
# IPv4

type_ok  'IPv4', '192.168.0.1',    'private address';
type_ok  'IPv4', '0.0.0.0',        'all-zeros';
type_ok  'IPv4', '255.255.255.255', 'broadcast';
type_ok  'IPv4', '192.168.1',      'NetAddr::IP accepts short-form (treats as 192.168.1.0)';

type_nok 'IPv4', '::1',            'IPv6 loopback rejected';
type_nok 'IPv4', '2001:db8::1',    'IPv6 address rejected';
type_nok 'IPv4', '256.0.0.1',      'octet > 255';
type_nok 'IPv4', '',               'empty string';

###########################################################################
# IPv6

type_ok  'IPv6', '::1',                                     'loopback';
type_ok  'IPv6', '2001:db8::1',                             'abbreviated';
type_ok  'IPv6', '2001:0db8:0000:0000:0000:0000:0000:0001', 'fully expanded';
type_ok  'IPv6', 'fe80::1',                                 'link-local';

type_nok 'IPv6', '192.168.1.1',  'IPv4 rejected';
type_nok 'IPv6', 'gggg::1',      'invalid hex group';
type_nok 'IPv6', '',             'empty string';
type_nok 'IPv6', undef,          'undef';

done_testing;
