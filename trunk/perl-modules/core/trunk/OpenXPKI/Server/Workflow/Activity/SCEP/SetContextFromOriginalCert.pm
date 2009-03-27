# OpenXPKI::Server::Workflow::Activity::SCEP::SetContextFromOriginalCert
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEP::SetContextFromOriginalCert;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $pki_realm  = CTX('session')->get_pki_realm();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $context    = $workflow->context();
    my $identifier = $context->param('current_identifier');
    my $dbi         = CTX('dbi_backend');

    # select current certificate from database
    my $cert = $dbi->first(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'SUBJECT',
            'ROLE',
        ],
        DYNAMIC => {
            'IDENTIFIER' => $identifier,
            'STATUS'    => 'ISSUED',
            'PKI_REALM' => $pki_realm,
        },
    );

    $context->param('cert_subject' => $cert->{SUBJECT});
    $context->param('cert_role' => $cert->{ROLE}); 

    # select subject alt names from database
    my $sans = $dbi->select(
        TABLE   => 'CERTIFICATE_ATTRIBUTES',
        COLUMNS => [
            'ATTRIBUTE_VALUE',
        ],
        DYNAMIC => {
            'ATTRIBUTE_KEY' => 'subject_alt_name',
            'IDENTIFIER'    => $identifier,
        },
    );

    ##! 64: 'sans: ' . Dumper $sans
    my @subject_alt_names;
    if (defined $sans) {
        foreach my $san (@{$sans}) {
            my @split = split q{:}, $san->{'ATTRIBUTE_VALUE'};
            push @subject_alt_names, \@split;
        }
    }
#    my @subject_alt_names = $self->_get_san_array_from_csr_obj($csr_obj);

#    ##! 64: 'subject_alt_names: ' . Dumper(\@subject_alt_names)
    
    $context->param('cert_subject_alt_name' =>
                    $serializer->serialize(\@subject_alt_names));

    my $sources = {
        'cert_subject'           => 'EXTERNAL',
        'cert_role'              => 'EXTERNAL',
        'cert_subject_alt_name_parts'  => 'EXTERNAL',
    };
    $context->param('sources' =>
                    $serializer->serialize($sources));
 
    # also look up the certificate profile from the corresponding
    # issuance workflow
    my $workflows = CTX('api')->search_workflow_instances({
        CONTEXT => [
            {
                KEY   => 'cert_identifier',
                VALUE => $identifier,
            },
        ],
        TYPE    => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE',
    });
    ##! 64: 'workflows: ' . Dumper $workflows;
    if (ref $workflows ne 'ARRAY') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SCEP_SETCONTEXTFROMORIGINALCERT_SEARCH_FOR_ISSUANCE_WORKFLOW_BY_CERT_IDENTIFIER_FAILED',
        );
    }
    if (scalar @{ $workflows } != 1) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SCEP_SETCONTEXTFROMORIGINALCERT_SEARCH_FOR_ISSUANCE_WORKFLOW_BY_CERT_IDENTIFIER_MORE_THAN_ONE_HIT',
        );
    }
    my $wf_id = $workflows->[0]->{'WORKFLOW.WORKFLOW_SERIAL'};
    my $wf_info = CTX('api')->get_workflow_info({
        WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE',
        ID       => $wf_id,
    });
    ##! 64: 'wf_info: ' . Dumper $wf_info
    $context->param(
        'cert_profile' => $wf_info->{WORKFLOW}->{CONTEXT}->{'cert_profile'},
    );

    return 1;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEP::SetContextFromOriginalCert

=head1 Description

This activity sets the relevant context fields used for certificate
issuance from the currently valid certificate given in the context
field current_identifier.
