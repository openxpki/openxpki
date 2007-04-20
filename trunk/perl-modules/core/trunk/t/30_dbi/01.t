use strict;
use warnings;
use English;
use Test::More;
plan tests => 8;

diag "OpenXPKI::Server::DBI: Database Initialization\n";

BEGIN {
    use_ok('OpenXPKI::Server::DBI', 'Using OpenXPKI::Server::DBI');
}

our %config;
our $dbi;
require 't/30_dbi/common.pl';

ok(1);

## dryrun of database schema init
my $sqlscript = eval { $dbi->init_schema (MODE => "DRYRUN") };
ok(! $EVAL_ERROR, 'DRYRUN mode') or diag $EVAL_ERROR;
ok(length($sqlscript) > 1000, 'Length of SQL script');

## database schema init
$sqlscript = eval { $dbi->init_schema () };
ok(! $EVAL_ERROR, 'init_schema') or diag $EVAL_ERROR;

1;
