use strict;
use warnings;
use Test::More;
plan tests => 6;

diag "OpenXPKI::Server::DBI: Performance (planned)\n";

use OpenXPKI::Server::DBI;

ok (1);

our %config;
our $dbi;
require 't/30_dbi/common.pl';

ok (1);

1;
