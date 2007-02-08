# OpenXPKI::Server::Workflow::Activity::CertIssuance::Issue
# Written by Martin Bartosch & Alexander Klink for 
# the OpenXPKI project 2005, 2006
# Copyright (c) 2005, 2006 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::CertIssuance::Issue;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CertIssuance::Issue';
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    my $self = shift;
    my $workflow = shift;

    $self->SUPER::execute($workflow,
			  {
			      ACTIVITYCLASS => 'CA',
			      PARAMS => {
				  _cert_profile => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
				  ca => {
				      accept_from => [ 'context' ], 
				      required => 1,
				  },
				  pkcs10 => {
				      accept_from => [ 'context' ],
				      required => 0,
				  },
				  spkac => {
				      accept_from => [ 'context' ],
				      required => 0,
				  },
				  cert_subject => {
				      accept_from => [ 'context' ], 
				      required => 1,
				  },
				  csr_type => {
				      accept_from => [ 'context' ], 
				      required => 1,
				  },
			      },
			  });    
    

    my $context = $workflow->context();
    ##! 32: 'context: ' . Dumper($context)
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $dbi = CTX('dbi_backend');

    my $token = CTX('pki_realm')->{$self->{PKI_REALM}}->{ca}->{id}->{$self->param('ca')}->{crypto};
    if (! defined $token) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_CERTIFICATEISSUANCE_ISSUE_TOKEN_UNAVAILABLE",
            );
    }

    my $profile = $self->param('_cert_profile');
    ##! 16: 'profile: ' . $profile

    my $cert_subj_alt_name = $context->param('cert_subject_alt_name');
    ##! 16: 'cert_subj_alt_name: ' . $cert_subj_alt_name
    my $subj_alt_name = $serializer->deserialize($cert_subj_alt_name);
    ##! 16: 'subj_alt_name: ' . Dumper($subj_alt_name)
    if (scalar @{$subj_alt_name} != 0) {
        $profile->set_subject_alt_name($subj_alt_name);
    }

    # determine serial number (atomically)
    my $serial = $dbi->get_new_serial(
        TABLE => 'CERTIFICATE',
    );
    $profile->set_serial($serial);

    $profile->set_subject($self->param('cert_subject'));

    my $csr;
    my $csr_type = $self->param('csr_type');
    ##! 16: 'csr_type: ' . $csr_type
    if ($csr_type eq 'pkcs10') {
        $csr = $self->param('pkcs10');
    }
    elsif ($csr_type eq 'spkac') {
        $csr = "\nSPKAC=" . $self->param('spkac');
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
	MESSAGE => "CA '" . $self->param('ca') . "' issued certificate with serial $serial and DN=" . $profile->get_subject() . " in PKI realm '" . $self->{PKI_REALM} . "'",
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
    ##! 16: 'cert_pem: ' . $cert_pem
    $context->param(certificate => $cert_pem),
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
