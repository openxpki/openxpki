package OpenXPKI::Server::Workflow::Activity::CSR::PersistRequest;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use Crypt::PKCS10 1.8;
use Workflow::Exception qw( workflow_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;


sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $pki_realm  = CTX('session')->data->pki_realm;
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $dbi        = CTX('dbi');

    my $type = $self->param('csr_type') || 'pkcs10';

    configuration_error('Invalid value given for request type (only pkcs10 is supported)')
        if ($type ne 'pkcs10');

    my $profile = $self->param('cert_profile');
    $profile = $context->param('cert_profile') unless ($profile);

    configuration_error('No profile given to PersistCSR')
        unless ($profile);

    my $subject = $self->param('cert_subject');
    $subject = $context->param('cert_subject') unless($subject);

    configuration_error('No subject given to PersistCSR')
        unless(defined $subject);

    my $data = $context->param('pkcs10');

    configuration_error('No PKCS10 request container given to PersistCSR')
        unless($data);


    if (!$self->param('keepformat')) {
        Crypt::PKCS10->setAPIversion(1);
        my $csr = Crypt::PKCS10->new( $data, ignoreNonBase64 => 1, verifySignature => 0  );

        workflow_error('Unable to parse PKCS10 container in CSR::PersistRequest')
            unless($csr);

        $data = $csr->csrRequest(1);
    }

    my $source_ref = $serializer->deserialize($context->param('sources')) || {};

    my $csr_serial = $dbi->next_id('csr');

    $dbi->insert(
        into => 'csr',
        values => {
            'pki_realm'  => $pki_realm,
            'req_key'    => $csr_serial,
            'format'     => $type,
            'data'       => $data,
            'profile'    => $profile,
            'subject'    => $subject,
        }
    );

    my $san_serialized = $context->param('cert_subject_alt_name');
    if ($san_serialized) {
        my $subj_alt_names = $serializer->deserialize($san_serialized);

        # Required as serialized value can be undef
        my @subj_alt_names;
        @subj_alt_names = @{$subj_alt_names} if ($subj_alt_names);
        ##! 16: '$subj_alt_names: ' . Dumper($subj_alt_names)
        ##! 16: '@subj_alt_names: ' . Dumper(\@subj_alt_names)

        my $san_source = $source_ref->{'cert_subject_alt_name_parts'} ||
            $source_ref->{'cert_subject_alt_name'} || '';

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
        my $val = $self->param($validity_param) || $context->param($validity_param);
        if ($val) {
            my $source = $source_ref->{$validity_param} || '';
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
                    'attribute_source'     => $source_ref->{'cert_info'} || '',
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

Anything other than pkcs10 was removed so I<pkcs10> is the default and
also the single value that is supported.

=item keepformat

By default, PKCS10 requests are reformatted to a normalized format,
which is removal of all whitespace and non-base64 characters and proper
line wrap. This is very important as current openssl version choke when
handling requests that are not formated as expected.

If you want to persist the CSR "as is", set this to a true value and the
incoming data will be written to the database without modifications.

=item cert_profile

The profile to use. Read from cert_profile context value if not set.

=item cert_subject

The subject to use. Read from cert_subject context value if not set.

=back
