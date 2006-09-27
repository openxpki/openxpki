# OpenXPKI::Server::Workflow::Activity::Tools::CreateWorkflowInstance.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::Tools::CreateWorkflowInstance;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;

sub execute
{
    my $self = shift;
    my $workflow = shift;
    my $serializer = OpenXPKI::Serialization::Simple->new();

    ## get needed informations
    my $context = $workflow->context();
    my $type    = $self->param('workflow_type');
    my $api     = CTX('api');

    ## create new workflow
    my $wf_info = $api->create_workflow_instance({
            WORKFLOW      => $type,
            FILTER_PARAMS => 1,
            PARAMS        => $context->param(),
    });

    my $wf_child_info_ref = {
        'ID'   => $wf_info->{WORKFLOW}->{ID},
        'TYPE' => $type,
    };

    # fetch wf_child_instances from workflow context
    # and add $wf_child_info_ref
    my @wf_children;
    my $wf_children_instances = $context->param('wf_children_instances');
    if (defined $wf_children_instances) {
        @wf_children = @{$serializer->deserialize($wf_children_instances)};
    }
    push @wf_children, $wf_child_info_ref;
    
    $context->param(
        'wf_children_instances'   => $serializer->serialize(\@wf_children),
    );
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CreateWorkflowInstance

=head1 Description

If you need to create a new instance of a workflow from within another
workflow then this is the right class. It takes the class which should
be instantiated from the activity parameter workflow_type. 

The workflow ID and type are saved in the serialized workflow context
parameter array wf_child_instances.

Example:
  <action name="I18N_OPENXPKI_WF_ACTION_SPAWN_CERT_ISSUANCE"
	  class="OpenXPKI::Server::Workflow::Activity::Tools::CreateWorkfowInstance"
	  workflow_type="I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE">
  </action>

