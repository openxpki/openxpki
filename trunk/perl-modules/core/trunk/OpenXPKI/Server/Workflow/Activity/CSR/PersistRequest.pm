# OpenXPKI::Server::Workflow::Activity::CSR:PersistRequest:
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CSR::PersistRequest;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $pki_realm  = CTX('session')->get_pki_realm();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $dbi        = CTX('dbi_backend');
    my $csr_serial = $dbi->get_new_serial(
        TABLE => 'CSR',
    );

    my $type    = $context->param('csr_type');
    if (! defined $type) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_PERSISTREQUEST_CSR_TYPE_UNDDEFINED',
        );
    }
    my $profile = $context->param('cert_profile');
    if (! defined $profile) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_PERSISTREQUEST_CSR_PROFILE_UNDDEFINED',
        );
    }
    my $subject = $context->param('cert_subject');
    if (! defined $subject) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_PERSISTREQUEST_CSR_SUBJECT_UNDDEFINED',
        );
    }
    my $role    = $context->param('cert_role');
    if (! defined $role) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_PERSISTREQUEST_CSR_ROLE_UNDDEFINED',
        );
    }

    my $subj_alt_names = $serializer->deserialize($context->param('cert_subject_alt_name'));

    my @subj_alt_names = @{$subj_alt_names};
    ##! 16: '$subj_alt_names: ' . Dumper($subj_alt_names)
    ##! 16: '@subj_alt_names: ' . Dumper(\@subj_alt_names)
    my $data;
    if ($type eq 'spkac') {
        $data = $context->param('spkac');
    }
    elsif ($type eq 'pkcs10') {
        $data = $context->param('pkcs10');
    }
    else {
        OpenXPKI::Exception->throw(
            message   => 'I18N_OPENXPKI_ACTIVITY_CSR_INSERTREQUEST_UNSUPPORTED_CSR_TYPE',
            params => {
                TYPE => $type,
            },
        );
    }

    # TODO: LOA (currently NULL)
    $dbi->insert(
        TABLE => 'CSR',
        HASH  => {
            'PKI_REALM'  => $pki_realm,
            'CSR_SERIAL' => $csr_serial,
            'TYPE'       => $type,
            'DATA'       => $data,
            'PROFILE'    => $profile,
            'SUBJECT'    => $subject,
            'ROLE'       => $role,
        },
    );

    my $source_ref = $serializer->deserialize($context->param('sources'));
    if (! defined $source_ref) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_CSR_PERSISTREQUEST_SOURCES_UNDEFINED',
        );
    }
    my $san_source = $source_ref->{'cert_subject_alt_name_parts'};

    if (! defined $san_source) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_CSR_PERSISTREQUEST_SUBJECT_ALT_NAME_SOURCE_UNDEFINED',
        );
    }

    foreach my $san (@subj_alt_names) {
        ##! 64: 'san: ' . $san
        my $attrib_serial = $dbi->get_new_serial(
            TABLE => 'CSR_ATTRIBUTES',
        );
        $dbi->insert(
            TABLE => 'CSR_ATTRIBUTES',
            HASH  => {
                'ATTRIBUTE_SERIAL' => $attrib_serial,
                'PKI_REALM'        => $pki_realm,
                'CSR_SERIAL'       => $csr_serial,
                'ATTRIBUTE_KEY'    => 'subject_alt_name',
                'ATTRIBUTE_VALUE'  => $serializer->serialize($san),
                'ATTRIBUTE_SOURCE' => $san_source,
            },
        );
    }
    foreach my $validity_param qw( notbefore notafter ) {
        if (defined $context->param($validity_param)) {
            my $source = $source_ref->{$validity_param};
            my $attrib_serial = $dbi->get_new_serial(
                TABLE => 'CSR_ATTRIBUTES',
            );
            $dbi->insert(
                TABLE => 'CSR_ATTRIBUTES',
                HASH  => {
                    'ATTRIBUTE_SERIAL' => $attrib_serial,
                    'PKI_REALM'        => $pki_realm,
                    'CSR_SERIAL'       => $csr_serial,
                    'ATTRIBUTE_KEY'    => $validity_param,
                    'ATTRIBUTE_VALUE'  => $context->param($validity_param),
                    'ATTRIBUTE_SOURCE' => $source,
                },
            );
        }
    }
    
    # process additional information (user configurable in profile)
    if (defined $context->param('cert_info')) {
	my $cert_info = $serializer->deserialize($context->param('cert_info'));
	##! 16: 'additional certificate information: ' . Dumper $cert_info
	
	foreach my $custom_key (keys %{$cert_info}) {
	    my $attrib_serial = $dbi->get_new_serial(
		TABLE => 'CSR_ATTRIBUTES',
		);
	    $dbi->insert(
		TABLE => 'CSR_ATTRIBUTES',
		HASH  => {
		    'ATTRIBUTE_SERIAL' => $attrib_serial,
		    'PKI_REALM'        => $pki_realm,
		    'CSR_SERIAL'       => $csr_serial,
		    'ATTRIBUTE_KEY'    => 'custom_' . $custom_key,
		    'ATTRIBUTE_VALUE'  => $cert_info->{$custom_key},
		    'ATTRIBUTE_SOURCE' => $source_ref->{'cert_info'},
		},
		);
	}
    }

    $dbi->commit();
    $context->param('csr_serial' => $csr_serial);
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CSR::PersistRequest

=head1 Description

persists the Certificate Signing Request into the database, so that
it can then be used by the certificate issuance workflow.
