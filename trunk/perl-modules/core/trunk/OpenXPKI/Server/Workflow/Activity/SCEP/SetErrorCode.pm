# OpenXPKI::Server::Workflow::Activity::SCEP::SetErrorCode
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::SCEP::SetErrorCode;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::SCEP::SetErrorCode';
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $error_code = $self->param('error_code');

    $context->param('error_code' => $error_code);

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEP::SetErrorCode

=head1 Description

This activity sets an error code which is used by the SCEP service to
return a corresponding error to the client. The error code is taken
from the activity definition.
