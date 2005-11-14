use strict;
use warnings;
use Test;
BEGIN { plan tests => 3 };

print STDERR "OpenXPKI::Server::DBI: Performance\n";

use OpenXPKI::Server::DBI;

ok (1);

our %config;
our $dbi;
require 't/dbi/common.pl';

ok (1);

1;
