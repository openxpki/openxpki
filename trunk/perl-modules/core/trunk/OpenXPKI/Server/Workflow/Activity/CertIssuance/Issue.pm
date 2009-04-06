# OpenXPKI::Server::Workflow::Activity::CertIssuance::Issue
# Written by Martin Bartosch & Alexander Klink for 
# the OpenXPKI project 2005, 2006
# Copyright (c) 2005, 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CertIssuance::Issue;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Crypto::X509;
use OpenXPKI::DateTime;

use Data::Dumper;
use MIME::Base64;

sub execute {
    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();
    ##! 32: 'context: ' . Dumper($context)
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $dbi = CTX('dbi_backend');

    my $token = CTX('pki_realm_by_cfg')->{$self->config_id()}->{$self->{PKI_REALM}}->{ca}->{id}->{$context->param('ca')}->{crypto};
    if (! defined $token) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_CERTIFICATEISSUANCE_ISSUE_TOKEN_UNAVAILABLE",
            );
    }

    my $profile = $context->param('_cert_profile');
    ##! 16: 'profile: ' . $profile

    if (! defined $profile) {
        # if we are restarted, the '_cert_profile' context entry might
        # have been lost, we just execute the previous activity to
        # get it back ...
        OpenXPKI::Server::Workflow::Activity::CertIssuance::GetCertProfile::execute($self, $workflow);
        $context = $workflow->context();
        $profile = $context->param('_cert_profile');
        ##! 64: 'context: ' . Dumper $context
    }
    my $cert_subj_alt_name = $context->param('cert_subject_alt_name');
    ##! 16: 'cert_subj_alt_name: ' . $cert_subj_alt_name
    my $subj_alt_name = $serializer->deserialize($cert_subj_alt_name);
    ##! 16: 'subj_alt_name: ' . Dumper($subj_alt_name)
    if (scalar @{$subj_alt_name} != 0) {
        $profile->set_subject_alt_name($subj_alt_name);
    }

    my $rand_length = $profile->get_randomized_serial_bytes();
    my $increasing  = $profile->get_increasing_serials();
    
    my $random_data = '';
    if ($rand_length > 0) {
        $random_data = $token->command({
            COMMAND       => 'create_random',
            RANDOM_LENGTH => $rand_length,
        });
        $random_data = decode_base64($random_data);
    }

    # determine serial number (atomically)
    my $serial = $dbi->get_new_serial(
        TABLE         => 'CERTIFICATE',
        INCREASING    => $increasing,
        RANDOM_LENGTH => $rand_length,
        RANDOM_PART   => $random_data,
    );
    $profile->set_serial($serial);

    $profile->set_subject($context->param('cert_subject'));


    if (defined $context->param('notbefore')) {
        $profile->set_notbefore(
            OpenXPKI::DateTime::get_validity({
                VALIDITY_FORMAT => 'absolutedate',
                VALIDITY        => $context->param('notbefore'),
            })
        );
    }
    if (defined $context->param('notafter')) {
        $profile->set_notafter(
            OpenXPKI::DateTime::get_validity({
                VALIDITY_FORMAT => 'absolutedate',
                VALIDITY        => $context->param('notafter'),
            })
        );
    }

    my $csr;
    my $csr_type = $context->param('csr_type');
    ##! 16: 'csr_type: ' . $csr_type
    if ($csr_type eq 'pkcs10') {
        $csr = $context->param('pkcs10');
    }
    elsif ($csr_type eq 'spkac') {
        # $csr = "\nSPKAC=" . $context->param('spkac');
        $csr = $context->param('spkac');
    }
    else { 
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_ACTIVITY_CERTIFICATEISSUANCE_ISSUE_UNSUPPORTED_CSR_TYPE',
        );
    }
    ##! 16: 'csr: ' . $csr
    my $cert = $token->command({COMMAND => "issue_cert",
			        PROFILE => $profile,
			        CSR     => $csr,
    });
    CTX('log')->log(
	MESSAGE => "CA '" . $context->param('ca') . "' issued certificate with serial $serial and DN=" . $profile->get_subject() . " in PKI realm '" . $self->{PKI_REALM} . "'",
	PRIORITY => 'info',
	FACILITY => [ 'audit', 'system', ],
	);

    my $cert_pem;
    if ($csr_type eq 'spkac') {
        $cert_pem = $token->command({
                        COMMAND => "convert_cert",
                        DATA    => $cert,
                        OUT     => "PEM",
                        IN      => "DER",
        });
    }
    elsif ($csr_type eq 'pkcs10') {
        $cert_pem = $cert;
    }
    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA  => $cert_pem,
        TOKEN => $token,
    );
    my $cert_identifier = $x509->get_identifier();
    ##! 16: 'cert_pem: ' . $cert_pem
    $context->param(certificate => $cert_pem);
    $context->param('cert_identifier' => $cert_identifier);
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Certificate::Issue

=head1 Description

Implements the Certificate Issuance workflow activity.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item _cert_profile

Certificate profile object to use for issuance.

=item ca

Issuing CA name to delegate certificate issuance to.

=item pkcs10request

Certificate request (PKCS#10, PEM encoded) to process, OR

=item spkac

The SPKAC request data

=item subject

Subject DN to use for certificate issuance.

=back

After completion the following context parameters will be set:

=over 12

=item certificate
    
PEM encoded certificate

=back

=head1 Functions

=head2 execute

Executes the action.
