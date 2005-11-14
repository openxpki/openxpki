use strict;
use warnings;
use Test;
BEGIN { plan tests => 3 };

print STDERR "OpenXPKI::Server::DBI: CA setup and empty CRL\n";

use OpenXPKI::Server::DBI;

ok (1);

our $dbi;
our $token;
require 't/dbi/common.pl';

ok (1);

## create crypto stuff

## put the CA stuff into the database

1;
