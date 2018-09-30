package TestWorkflowTimingCountAction;

use warnings;
use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

sub execute {
    my ($self, $workflow) = @_;

    open my $fh, '>>', $ENV{OXI_TESTENV_ROOT} . '/TestWorkflowTiming_counter';
    print $fh "x";
    close $fh;
}

1;
