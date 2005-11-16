use strict;
use warnings;
use Test;
BEGIN { plan tests => 6 };

print STDERR "OpenXPKI::Server::DBI: normal certificate workflow\n";

use OpenXPKI::Server::DBI;

ok (1);

our %config;
our $dbi;
require 't/30_dbi/common.pl';

ok (1);

1;
