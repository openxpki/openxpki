# OpenXPKI::Server::Workflow::Activity::SmartCard::IssueCert
# Written by Martin Bartosch for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::IssueCert;

use strict;
use warnings;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Debug;
use MIME::Base64;
use English;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $realm = CTX('session')->get_pki_realm();

#    my $role       = $self->param('role');
#    ##! 64: 'role from config file: ' . $role

    my $queue_key = $self->param('csr_queue_key') || 'csr_serial';

    my $csrs = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	{ 
	    workflow => $workflow,
	    context_key => $queue_key,
	} );

    my $csr_serial = $csrs->shift();

    ##! 64: 'checking csr serial validity: ' . $csr_serial
    if (! defined $csr_serial) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_ISSUECERT_CSR_SERIAL_UNDEFINED',
        );
    }
    
    # get a fresh view of the database
    CTX('dbi_backend')->commit();

    my $csr = CTX('dbi_backend')->first(
        TABLE   => 'CSR',
        DYNAMIC => {
            'CSR_SERIAL' => $csr_serial,
        },
    );
    if (! defined $csr) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_ISSUECERT_CSR_NOT_IN_DATABASE',
        );
    }

    if ($csr->{TYPE} ne 'pkcs10') {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_ISSUECERT_CSR_UNSUPPORTED_REQUEST_TYPE',
	    params => {
		TYPE => $csr->{TYPE},
	    },
        );
    }
    ##! 64: 'csr: ' . Dumper $csr

    my $cert_profile = $csr->{PROFILE};
    ##! 64: 'certificate profile: ' . $cert_profile

    my $issuing_ca = CTX('api')->determine_issuing_ca(
	{
	    PROFILE => $cert_profile,
	    CONFIG_ID => $self->config_id(),
	});
    ##! 64: 'issuing ca: ' . $issuing_ca

    my $certificate = CTX('pki_realm_by_cfg')->{$self->config_id()}->{$realm}->{ca}->{id}->{$issuing_ca}->{certificate};
    my $ca_token = CTX('pki_realm_by_cfg')->{$self->config_id()}->{$realm}->{ca}->{id}->{$issuing_ca}->{crypto};

    if (!defined $ca_token) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_ISSUECERT_CA_TOKEN_UNAVAILABLE',
        );
    }

    ##! 64: 'preparing certificate profile'
    my $profile = OpenXPKI::Crypto::Profile::Certificate->new(
	CONFIG    => CTX('xml_config'),
	PKI_REALM => CTX('api')->get_pki_realm(),
	CA        => $issuing_ca,
	ID        => $cert_profile,
	TYPE      => 'ENDENTITY', # no self-signed CA certs here(?)
	CONFIG_ID => $self->config_id(),
    );

    ##! 64: 'propagating cert subject: ' . $csr->{SUBJECT}
    $profile->set_subject($csr->{SUBJECT});

    my @subject_alt_names;
    my $csr_metadata = CTX('dbi_backend')->select(
	TABLE   => 'CSR_ATTRIBUTES',
        DYNAMIC => {
            'CSR_SERIAL' => $csr_serial,
        },
	);

    my $notbefore;
    my $notafter;

    foreach my $metadata (@{$csr_metadata}) {
        if ($metadata->{ATTRIBUTE_KEY} eq 'subject_alt_name') {
            push @subject_alt_names, 
	    $serializer->deserialize($metadata->{ATTRIBUTE_VALUE});
        } elsif ($metadata->{ATTRIBUTE_KEY} eq 'notbefore') {
	    $notbefore = $metadata->{ATTRIBUTE_VALUE};
	} elsif ($metadata->{ATTRIBUTE_KEY} eq 'notafter') {
	    $notafter = $metadata->{ATTRIBUTE_VALUE};
	}
    }

    if (scalar @subject_alt_names) {
	##! 64: 'propagating subject alternative names: ' . Dumper \@subject_alt_names
	$profile->set_subject_alt_name(\@subject_alt_names);
    }


    my $rand_length = $profile->get_randomized_serial_bytes();
    my $increasing  = $profile->get_increasing_serials();
    
    my $random_data = '';
    if ($rand_length > 0) {
        $random_data = $ca_token->command({
            COMMAND       => 'create_random',
            RANDOM_LENGTH => $rand_length,
        });
        $random_data = decode_base64($random_data);
    }

    # determine serial number (atomically)
    my $serial = CTX('dbi_backend')->get_new_serial(
        TABLE         => 'CERTIFICATE',
        INCREASING    => $increasing,
        RANDOM_LENGTH => $rand_length,
        RANDOM_PART   => $random_data,
    );
    ##! 64: 'propagating serial number: ' . $serial
    $profile->set_serial($serial);

    if (defined $notbefore) {
	##! 64: 'propagating notbefore date: ' . $notbefore
        $profile->set_notbefore(
            OpenXPKI::DateTime::get_validity({
                VALIDITY_FORMAT => 'absolutedate',
                VALIDITY        => $notbefore,
            })
        );
    }

    if (defined $notafter) {
	##! 64: 'propagating notafter date: ' . $notafter
        $profile->set_notafter(
            OpenXPKI::DateTime::get_validity({
                VALIDITY_FORMAT => 'absolutedate',
                VALIDITY        => $notafter,
            })
        );
    }

    ##! 64: 'performing key online test'
    if (! $ca_token->key_usable()) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_ISSUECERT_CA_KEY_UNUSABLE',
        );
    }
    ##! 64: 'issuing certificate'
    my $cert = $ca_token->command(
	{
	    COMMAND => "issue_cert",
	    PROFILE => $profile,
	    CSR     => $csr->{DATA},
	});

    CTX('log')->log(
	MESSAGE => "CA '$issuing_ca' issued certificate with serial $serial and DN=" . $profile->get_subject() . " in PKI realm '" . CTX('api')->get_pki_realm() . "'",
	PRIORITY => 'info',
	FACILITY => [ 'audit', 'system', ],
	);
    ##! 16: 'cert: ' . $cert
    
    ##! 64: 'parsing generated certificate'
    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA  => $cert,
        TOKEN => $ca_token,
	);

    ##! 64: 'persisting certificate'
    my %insert_hash = $x509->to_db_hash();
    my $identifier = $insert_hash{'IDENTIFIER'};

    my $ca_identifier = CTX('pki_realm_by_cfg')->{$self->config_id()}->{CTX('api')->get_pki_realm()}->{ca}->{id}->{$issuing_ca}->{identifier};

    $insert_hash{'PKI_REALM'}         = CTX('api')->get_pki_realm();
    $insert_hash{'ISSUER_IDENTIFIER'} = $ca_identifier;
    $insert_hash{'ROLE'}              = $csr->{ROLE}; 
    $insert_hash{'CSR_SERIAL'}        = $csr_serial;
    $insert_hash{'STATUS'}            = 'ISSUED';
    CTX('dbi_backend')->insert(
        TABLE => 'CERTIFICATE',
        HASH  => \%insert_hash,
    );

    my @parsed_subject_alt_names = $x509->get_subject_alt_names();
    ##! 32: 'sans: ' . Dumper \@subject_alt_names
    ##! 32: 'sans (parsed): ' . Dumper \@parsed_subject_alt_names
    foreach my $san (@parsed_subject_alt_names) {
        my $serial = CTX('dbi_backend')->get_new_serial(
            TABLE => 'CERTIFICATE_ATTRIBUTES',
        );
        CTX('dbi_backend')->insert(
            TABLE => 'CERTIFICATE_ATTRIBUTES',
            HASH  => {
                'ATTRIBUTE_SERIAL' => $serial,
                'IDENTIFIER'       => $identifier,
                'ATTRIBUTE_KEY'    => 'subject_alt_name',
                'ATTRIBUTE_VALUE'  => $san->[0] . ':' . $san->[1],
            },
        );
    }
    CTX('dbi_backend')->commit();
    
#    $context->param(certificate => $cert);
    $context->param('cert_identifier' => $identifier);

    # inform successor that an escrow cert was generated
    $context->param('have_new_escrow_cert', 'yes');

    # if requested in the configuration push the current cert identifier
    # to the specified context array
    if (defined $self->param('issuance_queue_key')) {
	my $certs_issued = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    { 
		workflow => $workflow,
		context_key => $self->param('issuance_queue_key'),
	    } );
	$certs_issued->push($identifier);
    }

    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::IssueCert

=head1 Description

Inline certificate issuance function. Takes the first CSR from the
certificate request queue, prepares the certificate profile, 
determines the issuing CA and issues the certificate.

=head1 Examples
    <action name="scpers_issue_certificate"
            class="OpenXPKI::Server::Workflow::Activity::SmartCard::IssueCert"
            csr_queue_key="csr_serials_to_process"
            issuance_queue_key="certs_issued">
            <field name="csr_serials_to_process" is_required="yes"/>
    </action>

=head1 Parameters

=head2 csr_queue_key

Context parameter name to access for fetching the next CSR to process.
Expects a serialized array of CSR serial numbers. The CSR must already
exist in the database. Default: csr_serial

=head2 issuance_queue_key

Optional. Context parameter name specifying a workflow context array
that will contain the certificate identifiers of the issued certificates.

