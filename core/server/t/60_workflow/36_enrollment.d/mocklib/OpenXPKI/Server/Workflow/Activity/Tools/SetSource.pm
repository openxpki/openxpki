package OpenXPKI::Server::Workflow::Activity::Tools::SetSource;

use strict;

use base qw( Workflow::Action );

use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;

    my $context   = $workflow->context();

    return 1;
}

1;

