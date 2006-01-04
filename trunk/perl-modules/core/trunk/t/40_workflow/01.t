use strict;
use warnings;
use Data::Dumper;
use Test;

# use Smart::Comments;

use Workflow::Factory qw( FACTORY );

BEGIN { plan tests => 3 };

our $basedir;
require 't/40_workflow/common.pl';

print STDERR "OpenXPKI::Server::Workflow - Initialization\n";


if (! -d "$basedir/db") {
    mkdir "$basedir/db";
}

ok(-d "$basedir/db");
