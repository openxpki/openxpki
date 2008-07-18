# OpenXPKI::Server::Workflow::Activity::SmartCard::WriteCertificateToInstall
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::WriteCertificateToInstall;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use URI::Escape;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $api = CTX('api');
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $pki_realm = CTX('api')->get_pki_realm();
    my $tm = CTX('crypto_layer');

    my $certs_installed = 0;
    if (defined $context->param('certs_installed')) {
        $certs_installed = $context->param('certs_installed');
    }
    ##! 16: 'certs installed: ' . $certs_installed
    my $wf_children = $context->param('wf_children_instances');
    if (!defined $wf_children) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_WRITECERTIFICATETOINSTALL_NO_WF_CHILDREN',
        );
    }
    my @wf_children = @{$serializer->deserialize($wf_children)};
    my $child_id   = $wf_children[$certs_installed]->{ID};
    my $child_type = $wf_children[$certs_installed]->{TYPE};

    my $wf_info = $api->get_workflow_info({
        WORKFLOW => $child_type,
        ID       => $child_id,
    });
    
    my $certificate = $wf_info->{WORKFLOW}->{CONTEXT}->{certificate};
    my $ca_id       = $wf_info->{WORKFLOW}->{CONTEXT}->{ca};
    if (!defined $certificate) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_WRITECERTIFICATETOINSTALL_NO_CERTIFICATE_IN_CHILD_WORKFLOW',
        );
    }
    
    ##! 64: 'certificate: ' . $certificate
    $context->param('certificate' => $certificate);
    $certs_installed++;

    $context->param('certs_installed' => $certs_installed);
    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::WriteCertificateToInstall

=head1 Description

This class takes one of the issued certificates from the children workflows
and puts it into the context field 'certificate' (as PEM)
