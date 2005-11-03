use strict;
use warnings;
use Test;
BEGIN { plan tests => 3 };

print STDERR "OpenXPKI::Server::DBI\n";

use OpenXPKI::Server::DBI;

ok (1);

our %config;
require 't/dbi/common.pl';

ok (1);

my $dbi = OpenXPKI::Server::DBI->new (%config);

ok($dbi and ref $dbi);

1;
