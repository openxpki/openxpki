use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 8 };

print STDERR "OpenXPKI::Server::DBI: Database Initialization\n";

use OpenXPKI::Server::DBI;

ok (1);

our %config;
our $dbi;
require 't/30_dbi/common.pl';

ok(1);

## dryrun of database schema init
my $sqlscript = eval { $dbi->init_schema (MODE => "DRYRUN") };
if ($EVAL_ERROR)
{
    ok(0);
    print STDERR "Error: DRYRUN of init_schema failed (${EVAL_ERROR})\n";
}
elsif (length ($sqlscript) < 1000)
{
    ok(0);
    print STDERR "Error: SQL script looks like too short ($sqlscript)\n";
}
else
{
    ok(1);
}

## database schema init
$sqlscript = eval { $dbi->init_schema () };
if ($EVAL_ERROR)
{
    ok(0);
    print STDERR "Error: init_schema failed (${EVAL_ERROR})\n";
}
else
{
    ok(1);
}

1;
