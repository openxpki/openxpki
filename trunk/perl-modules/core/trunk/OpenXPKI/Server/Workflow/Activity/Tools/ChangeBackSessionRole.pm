# OpenXPKI::Server::Workflow::Activity::Tools::ChangeBackSessionRole
# Written by Alexander Klink for the OpenXPKI project
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 513 $

package OpenXPKI::Server::Workflow::Activity::Tools::ChangeBackSessionRole;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::DateTime;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::Tools::ChangeBackSessionRole';

sub execute {
    my $self = shift;
    my $workflow = shift;
    my $context  = $workflow->context();

    # get old role from context
    my $role = $context->param('old_role');

    CTX('session')->set_role($role);
    ##! 64: 'session role: ' . CTX('session')->get_role()

    return 1;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ChangeBackSessionRole

=head1 Description

Changes the role of the current session to the role previous to
calling ChangeSessionRole. This activity should be used as soon
as possible after calling ChangeSessionRole and the elevated role
is no longer needed.
