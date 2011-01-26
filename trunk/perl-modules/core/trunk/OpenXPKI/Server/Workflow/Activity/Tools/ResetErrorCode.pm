# OpenXPKI::Server::Workflow::Activity::Tools::ResetErrorCode
# Written by Scott Hardin for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::ResetErrorCode;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
#    my $error_code = $self->param('error_code');

    $context->param('error_code' => '');

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ResetErrorCode

=head1 Description

This activity sets an the error_code context parameter, which is
taken from the activity definition. This is typically called in
an activity with resulting_state="FAILURE", so that one can see
the reason why one ended up in FAILURE.
