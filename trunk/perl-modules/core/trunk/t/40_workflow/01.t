use strict;
use warnings;
use English;
use Data::Dumper;
use Test;

# use Smart::Comments;

BEGIN { plan tests => 0 };

our $basedir;
our $dbi;
require 't/40_workflow/common.pl';

print STDERR "OpenXPKI::Server::Workflow - Initialization\n";


# nothing to be done here (database is initialized in 30_dbi)
