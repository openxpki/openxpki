# OpenXPKI::Server::Workflow::Activity::CertIssuance::PersistCertificate
# Written by Alexander Klink for 
# the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CertIssuance::PersistCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;


use Data::Dumper;

sub execute {
    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();
    ##! 32: 'context: ' . Dumper($context)
    my $dbi = CTX('dbi_backend');
    my $pki_realm = CTX('api')->get_pki_realm(); 

    my $tm = CTX('crypto_layer');
    my $default_token = $tm->get_token(
        TYPE      => 'DEFAULT',
        PKI_REALM => $pki_realm,
    );

    if (! defined $default_token) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_CERTIFICATEISSUANCE_INSERT_CERTIFICATE_TOKEN_UNAVAILABLE",
            );
    }

    my $certificate = $context->param('certificate');

    my $x509 = OpenXPKI::Crypto::X509->new(
        TOKEN => $default_token,
        DATA  => $certificate,
    );
    ##! 32: 'x509: ' . Dumper $x509
    my %insert_hash = $x509->to_db_hash();
    my $identifier = $insert_hash{'IDENTIFIER'};
    my $ca = $context->param('ca');
    my $ca_identifier = CTX('pki_realm_by_cfg')->{$self->config_id()}->{$pki_realm}->{ca}->{id}->{$ca}->{identifier};
    $insert_hash{'PKI_REALM'} = $pki_realm;
    $insert_hash{'ISSUER_IDENTIFIER'} = $ca_identifier;
    $insert_hash{'ROLE'}       = $context->param('cert_role'); 
    $insert_hash{'CSR_SERIAL'} = $context->param('csr_serial');
    $insert_hash{'STATUS'} = 'ISSUED';
    $dbi->insert(
        TABLE => 'CERTIFICATE',
        HASH  => \%insert_hash,
    );

    my @subject_alt_names = $x509->get_subject_alt_names();
    ##! 32: 'sans: ' . Dumper \@subject_alt_names
    foreach my $san (@subject_alt_names) {
        my $serial = $dbi->get_new_serial(
            TABLE => 'CERTIFICATE_ATTRIBUTES',
        );
        $dbi->insert(
            TABLE => 'CERTIFICATE_ATTRIBUTES',
            HASH  => {
                'ATTRIBUTE_SERIAL' => $serial,
                'IDENTIFIER'       => $identifier,
                'ATTRIBUTE_KEY'    => 'subject_alt_name',
                'ATTRIBUTE_VALUE'  => $san->[0] . ':' . $san->[1],
            },
        );
    }

    # persist additional (custom) information
    if (defined $context->param('cert_info')) {
	my $serializer = OpenXPKI::Serialization::Simple->new();

	my $cert_info = $serializer->deserialize($context->param('cert_info'));
	##! 16: 'additional certificate information: ' . Dumper $cert_info

	foreach my $key (keys %{$cert_info}) {
	    my $value = $cert_info->{$key};

	    my $serial = $dbi->get_new_serial(
		TABLE => 'CERTIFICATE_ATTRIBUTES',
		);
	    $dbi->insert(
		TABLE => 'CERTIFICATE_ATTRIBUTES',
		HASH  => {
		    'ATTRIBUTE_SERIAL' => $serial,
		    'IDENTIFIER'       => $identifier,
		    'ATTRIBUTE_KEY'    => 'custom_' . $key,
		    'ATTRIBUTE_VALUE'  => $value,
		},
		);
	}
	
    }

    $dbi->commit();
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Certificate::PersistCertificate

=head1 Description

Persists the issued certificate into the certificate database

=head2 Context parameters

Expects the following context parameter:

=over 12

=item certificate

The certificate in PEM format

=back

=head1 Functions

=head2 execute

Executes the action.
