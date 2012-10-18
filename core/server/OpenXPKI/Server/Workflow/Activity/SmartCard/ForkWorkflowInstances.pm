# OpenXPKI::Server::Workflow::Activity::SmartCard:ForkWorkflowInstances:
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::ForkWorkflowInstances;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
# the following is a bit of a hack, we use the activity class to
# fork each workflow instance
use OpenXPKI::Server::Workflow::Activity::Tools::ForkWorkflowInstance;

use Data::Dumper;

sub execute {
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $role       = $self->param('role');
    my $sleep      = $self->param('sleep');
    ##! 64: 'role from config file: ' . $role
    my $csr_serials = $context->param('csr_serial');
    if (!defined $csr_serials) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_FORKWORKFLOWINSTANCES_CSR_SERIALS_UNDEFINED',
        );
    }
    
    my @csr_serials = @{$serializer->deserialize($csr_serials)};

    foreach my $serial (@csr_serials) {
        ##! 64: 'csr_serial: ' . $serial
        my $fork_wf_instance = OpenXPKI::Server::Workflow::Activity::Tools::ForkWorkflowInstance->new(
            $workflow,
            {},
        );
        ##! 64: 'instantiated'
        $fork_wf_instance->execute(
            $workflow,
            'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE',
            {
                'csr_serial' => $serial,
                'role'       => $role,
            },
        );
        ##! 64: 'executed'
       if (defined $sleep && ($sleep =~ m{ \A \d+ \z }xms)) {
           ##! 64: 'sleeping ' . $sleep . ' seconds'
           sleep $sleep;
       }
    }
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::ForkWorkflowInstances

=head1 Description

Forks certificate issuance workflows for all csr_serials in the
context.

parameters:

sleep:           (optional) sleep n seconds after each fork operation
