# OpenXPKI::Server::Workflow::Activity::CertIssuance::ImportCertData
# Written by Alexander Klink for 
# the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CertIssuance::ImportCertData;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;

    my $context    = $workflow->context();
    ##! 32: 'context: ' . Dumper($context)
    my $dbi        = CTX('dbi_backend');
    my $pki_realm  = CTX('api')->get_pki_realm(); 
    my $csr_serial = $context->param('csr_serial');
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $csr = $dbi->first(
        TABLE   => 'CSR',
        DYNAMIC => {
            'CSR_SERIAL' => $csr_serial,
        },
    );
    $context->param('csr_type' => $csr->{TYPE});
    if ($csr->{TYPE} eq 'pkcs10') {
        $context->param('pkcs10' => $csr->{DATA});
    }
    elsif ($csr->{TYPE} eq 'spkac') {
        $context->param('spkac' => $csr->{DATA});
    }
    else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_CERTISSUANCE_IMPORTCERTDATA_INVALID_CSR_TYPE',
            params => {
                'CSR_TYPE' => $csr->{TYPE},
            },
        );
    }
    $context->param('cert_profile' => $csr->{PROFILE});
    $context->param('cert_subject' => $csr->{SUBJECT});
    $context->param('cert_role'    => $csr->{ROLE});

    my @subj_alt_names;
    my $cert_info = {};

    my $csr_metadata = $dbi->select(
        TABLE   => 'CSR_ATTRIBUTES',
        DYNAMIC => {
            'CSR_SERIAL' => $csr_serial,
        },
    );
    foreach my $metadata (@{$csr_metadata}) {
	my $key = $metadata->{ATTRIBUTE_KEY};
	my $value = $metadata->{ATTRIBUTE_VALUE};

        if ($key eq 'subject_alt_name') {
            push @subj_alt_names, 
                $serializer->deserialize($value);
        }
	elsif ($key eq 'notafter' ||
	       $key eq 'notbefore') {
            $context->param($key => $value);
        }
	elsif ($key =~ m{ \A custom_(.*) }xms) {
	    $cert_info->{$1} = $value;
	}
    }

    $context->param(
	'cert_subject_alt_name' => $serializer->serialize(\@subj_alt_names),
	);

    # propagate "additional information" stored in the request
    $context->param(
	'cert_info' => $serializer->serialize($cert_info),
	);

    ##! 32: 'context: ' . Dumper($context)
    return;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Certificate::ImportCertData

=head1 Description

Imports the certificate data (and metadata) into the context.

=head2 Context parameters

Expects the following context parameter:

=over 12

=item csr_serial

The certificate serial identifying the CSR in the database

=back

Writes the following context parameters:

=over 12

=item csr_type

The type of the CSR data (e.g. pkcs10 or spkac)

=item pkcs10 or spkac

The actual request data

=item cert_profile

The certificate profile to be used

=item cert_subject

The certificate subject

=item cert_subject_alt_name

A serialized array of subject alternative names

=item cert_role

The role associated with the certificate
=back

=back

=head1 Functions

=head2 execute

Executes the action.
