# OpenXPKI::Server::Workflow::Activity::Tools::ChangeSessionRole
# Written by Alexander Klink for the OpenXPKI project
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 513 $

package OpenXPKI::Server::Workflow::Activity::Tools::ChangeSessionRole;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::DateTime;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::Tools::ChangeSessionRole';

sub execute {
    my $self = shift;
    my $workflow = shift;
    my $context  = $workflow->context();

    # save old role in context
    $context->param('old_role' => CTX('session')->get_role());

    my $role = $self->param('role');
    ##! 64: 'configured role: ' . $role

    CTX('session')->set_role($role);
    ##! 64: 'session role: ' . CTX('session')->get_role()

    return 1;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ChangeSessionRole

=head1 Description

Changes the role of the current session to a configured role and
saves the old session role in the context.
Despite the little code, this has of course some security implications.
Only use this if you really have to (for example to automatically
issue a certificate after thorough validation of the request).
See the SCEP workflow for an example.
Should be changed back using the ChangeBackSessionRole activity
as soon as possible.
