use strict;
use warnings;
use Test::More;
plan tests => 6;

diag "OpenXPKI::Server::DBI: Quoting bug\n";

use OpenXPKI::Server::DBI;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Crypto::CRL;

use Data::Dumper;

our $dbi;
our $token;
require 't/30_dbi/common.pl';

$dbi->insert(
    TABLE => 'CERTIFICATE',
    HASH => 
    {
	  ISSUER_IDENTIFIER        => '1234',
      CERTIFICATE_SERIAL       => '1',
      SUBJECT                  => 'CN=Foo,O=Acme\, Inc',
    });

$dbi->commit();
ok(1, 'Inserted entry');

TODO: {
    local $TODO = 'MySQL seems to have a problem with quoting, see #1951540';
    my $result = $dbi->select(
        TABLE => 'CERTIFICATE',
        DYNAMIC => 
        {
          SUBJECT                  => 'CN=Foo,O=Acme\, Inc',
        }
    );
    is(scalar @{$result}, 1, 'one entry returned');
}

1;
