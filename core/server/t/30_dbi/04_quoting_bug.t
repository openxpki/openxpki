use strict;
use warnings;
use Test::More;
plan tests => 7;

diag "OpenXPKI::Server::DBI: Quoting bug\n" if $ENV{VERBOSE};

use OpenXPKI::Server::Database;

use Data::Dumper;

our $dbi;
our $token;
require 't/30_dbi/common.pl';

$dbi->insert(
    into => 'CERTIFICATE',
    values => 
    {
        issuer_identifier  => '1234',
        certificate_key    => '1',
        subject            => 'CN=Foo,O=Acme\, Inc',
    });

$dbi->commit();
ok(1, 'Inserted entry');


my $result = $dbi->select(
    table => 'certificate',
    where => {
        subject => 'CN=Foo,O=Acme\, Inc',
    }
);
is(scalar @{$result}, 1, 'one entry returned (equal)');

$result = $dbi->select(
    table => 'certificate',
    where => 
    {
        subject => { -like => 'CN=Foo,O=Acme\, Inc'},
    }
);
is(scalar @{$result}, 1, 'one entry returned');


1;
