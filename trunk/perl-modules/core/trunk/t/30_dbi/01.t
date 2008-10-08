use strict;
use warnings;
use English;
use Test::More;
plan tests => 9;

diag "OpenXPKI::Server::DBI: Database Initialization\n";

use_ok('OpenXPKI::Server::DBI', 'Using OpenXPKI::Server::DBI');

our %config;
our $dbi;
require 't/30_dbi/common.pl';

ok(1);

## dryrun of database schema init
my $sqlscript = eval { $dbi->init_schema (MODE => "DRYRUN") };
ok(! $EVAL_ERROR, 'DRYRUN mode') or diag $EVAL_ERROR;
ok(length($sqlscript) > 1000, 'Length of SQL script');
if ($ENV{DEBUG}) {
    diag $sqlscript;
}

## database schema init
$sqlscript = eval { $dbi->init_schema (MODE => 'FORCE') };
ok(! $EVAL_ERROR, 'init_schema') or diag $EVAL_ERROR;

1;
