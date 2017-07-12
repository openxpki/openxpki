# OpenXPKI::Server::Workflow::Activity::CSR:PersistRequest:
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CSR::PersistRequest;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use Crypt::PKCS10 1.8;
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
    my $pki_realm  = CTX('session')->data->pki_realm;
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $dbi        = CTX('dbi');

    my $type = $self->param('csr_type') || 'pkcs10';

    my $profile = $context->param('cert_profile');
    if (! defined $profile) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_PERSISTREQUEST_CSR_PROFILE_UNDEFINED',
        );
    }
    my $subject = $context->param('cert_subject');
    if (! defined $subject) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_PERSISTREQUEST_CSR_SUBJECT_UNDEFINED',
        );
    }

    my $data;
    if ($type eq 'spkac') {
        $data = $context->param('spkac');
    }
    elsif ($type eq 'pkcs10') {
        $data = $context->param('pkcs10');

        if (!$self->param('keepformat')) {
            Crypt::PKCS10->setAPIversion(1);
            my $csr = Crypt::PKCS10->new( $data, ignoreNonBase64 => 1, verifySignature => 0  );
            if (!$csr) {
                OpenXPKI::Exception->throw(
                    message => 'Unable to parse PKCS10 container in CSR::PersistRequest'
                );
            }
            $data = $csr->csrRequest(1);
        }
    }
    else {
        OpenXPKI::Exception->throw(
            message   => 'I18N_OPENXPKI_ACTIVITY_CSR_INSERTREQUEST_UNSUPPORTED_CSR_TYPE',
            params => {
                TYPE => $type,
            },
        );
    }

    my $source_ref = $serializer->deserialize($context->param('sources'));
    if (! defined $source_ref) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_CSR_PERSISTREQUEST_SOURCES_UNDEFINED',
        );
    }

    my $csr_serial = $dbi->next_id('csr');

    $dbi->insert( into => 'csr', values => {
        'pki_realm'  => $pki_realm,
        'req_key'    => $csr_serial,
        'format'     => $type,
        'data'       => $data,
        'profile'    => $profile,
        'subject'    => $subject,
    });


    my $san_serialized = $context->param('cert_subject_alt_name');
    if ($san_serialized) {
        my $subj_alt_names = $serializer->deserialize($san_serialized);

        # Required as serialized value can be undef
        my @subj_alt_names;
        @subj_alt_names = @{$subj_alt_names} if ($subj_alt_names);
        ##! 16: '$subj_alt_names: ' . Dumper($subj_alt_names)
        ##! 16: '@subj_alt_names: ' . Dumper(\@subj_alt_names)

        my $san_source = $source_ref->{'cert_subject_alt_name_parts'};
        $san_source = $source_ref->{'cert_subject_alt_name'} unless($san_source);

        if (! defined $san_source) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_CSR_PERSISTREQUEST_SUBJECT_ALT_NAME_SOURCE_UNDEFINED',
            );
        }

        foreach my $san (@subj_alt_names) {
            ##! 64: 'san: ' . $san
            $dbi->insert(
                into => 'csr_attributes',
                values => {
                    'attribute_key'        => $dbi->next_id('csr_attributes'),
                    'pki_realm'            => $pki_realm,
                    'req_key'              => $csr_serial,
                    'attribute_contentkey' => 'subject_alt_name',
                    'attribute_value'      => $serializer->serialize($san),
                    'attribute_source'     => $san_source,
                },
            );
        }
    }

    foreach my $validity_param (qw( notbefore notafter )) {
        if (defined $context->param($validity_param)) {
            my $source = $source_ref->{$validity_param};
            my $val = $context->param($validity_param);
            ##! 16: $validity_param . ' ' .$val
            $dbi->insert(
                into => 'csr_attributes',
                values  => {
                    'attribute_key'        => $dbi->next_id('csr_attributes'),
                    'pki_realm'            => $pki_realm,
                    'req_key'              => $csr_serial,
                    'attribute_contentkey' => $validity_param,
                    'attribute_value'      => $val ,
                    'attribute_source'     => $source,
                },
            );
        }
    }

    # x509 extensions - array of extension items
    my $cert_ext = $context->param('cert_extension');
    if ($cert_ext) {
        foreach my $ext (@{$serializer->deserialize($cert_ext)}) {
            ##! 32: 'Persist x509 extension ' . Dumper $ext
            my $source = $source_ref->{'cert_extension'}->{$ext->{oid}} || '';
            $dbi->insert(
                into => 'csr_attributes',
                values => {
                    'attribute_key'        => $dbi->next_id('csr_attributes'),
                    'pki_realm'            => $pki_realm,
                    'req_key'              => $csr_serial,
                    'attribute_contentkey' => 'x509v3_extension',
                    'attribute_value'      => $serializer->serialize($ext),
                    'attribute_source'     => $source,
                },
            );
        }
    }

    # process additional information (user configurable in profile)
    if (defined $context->param('cert_info')) {
        my $cert_info = $serializer->deserialize($context->param('cert_info'));
        ##! 16: 'additional certificate information: ' . Dumper $cert_info

        foreach my $custom_key (keys %{$cert_info}) {

            # We can have array/hash values from the input, need serialize
            my $value = $cert_info->{$custom_key};
            if (ref $value) {
                ##! 32: 'Serializing non scalar item for key ' . $custom_key
                $value= $serializer->serialize( $value );
            }

            $dbi->insert(
                into => 'csr_attributes',
                values => {
                    'attribute_key'        => $dbi->next_id('csr_attributes'),
                    'pki_realm'            => $pki_realm,
                    'req_key'              => $csr_serial,
                    'attribute_contentkey' => 'custom_' . $custom_key,
                    'attribute_value'      => $value,
                    'attribute_source'     => $source_ref->{'cert_info'},
                }
            );
        }
    }

    $context->param('csr_serial' => $csr_serial);

    CTX('log')->application()->info("persisted csr for $subject with csr_serial $csr_serial");

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CSR::PersistRequest

=head1 Description

persists the Certificate Signing Request into the database, so that
it can then be used by the certificate issuance workflow.

=head2 Activity Parameters

=over

=item csr_type

pkcs10 (default) or spkac (not used currrently)

=item keepformat

By default, PKCS10 requests are reformatted to a normalized format, which
is removal of all whitespace and non-base64 characters and proper line wrap.
This is very important as current openssl version choke when handling
requests that are not formated as expected.

If you want to persist the CSR "as is", set this to a true value and we
wont touch it.

=back
