# OpenXPKI::Server::Workflow::Activity::Tools::CreateProcess.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::Tools::CreateProcess;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

sub execute
{
    my $self = shift;
    my $workflow = shift;

    ## get needed informations
    my $context = $workflow->context();
    my $type    = $context->param('create_workflow_type');
    my $api     = CTX('api');

    ## create new workflow
    $api = $api->get_api('Workflow');
    $api->create_workflow_instance ({WORKFLOW      => $type,
                                     FILTER_PARAMS => 1,
                                     PARAMS        => $context->param()});
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CreateProcess

=head1 Description

If you need to create a new instance of a workflow from within another
workflow then this is the right class. It takes the class which should
be instantiated from the context parameter workflow_type. Please note
that it is a good idea to configure this workflow type in the workflow
configuration and do not accept dynamic parameters.

The class name was choosen because we usually talk about processes as
instances from workflows.
