use strict;
use warnings;
use English;
use Data::Dumper;
use Test;

# use Smart::Comments;

use Workflow::Factory qw( FACTORY );

BEGIN { plan tests => 6 };

our $basedir;
our $dbi;
require 't/40_workflow/common.pl';

print STDERR "OpenXPKI::Server::Workflow - Initialization\n";


if (! -d "$basedir/db") {
    mkdir "$basedir/db";
}

ok(-d "$basedir/db");


## init database
eval { 
    $dbi->init_schema () 
};
if ($EVAL_ERROR)
{
    ok(0);
    print STDERR "Error: init_schema failed (${EVAL_ERROR})\n";
}
else
{
    ok(1);
}

$dbi->disconnect();
undef $dbi;
ok(1);

`cp t/40_workflow/sqlite.db t/40_workflow/sqlite_workflow.db`;
ok(not $CHILD_ERROR);
