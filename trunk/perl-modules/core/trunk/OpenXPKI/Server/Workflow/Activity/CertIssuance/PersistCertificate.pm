# OpenXPKI::Server::Workflow::Activity::CertIssuance::PersistCertificate
# Written by Alexander Klink for 
# the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::CertIssuance::PersistCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CertIssuance::PersistCertificate';
use OpenXPKI::Crypto::X509;
use OpenXPKI::Crypto::TokenManager;

use Data::Dumper;

sub execute {
    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();
    ##! 32: 'context: ' . Dumper($context)
    my $dbi = CTX('dbi_backend');
    my $pki_realm = CTX('api')->get_pki_realm(); 

    my $tm = OpenXPKI::Crypto::TokenManager->new();
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
    my %insert_hash = $x509->to_db_hash();
    my $ca = $context->param('ca');
    my $ca_identifier = CTX('pki_realm')->{$pki_realm}->{ca}->{id}->{$ca}->{identifier};
    $insert_hash{'PKI_REALM'} = $pki_realm;
    $insert_hash{'ISSUER_IDENTIFIER'} = $ca_identifier;
    $insert_hash{'ROLE'}       = $context->param('cert_role'); 
    $insert_hash{'CSR_SERIAL'} = $context->param('csr_serial');
    $insert_hash{'STATUS'} = 'VALID';
    $dbi->insert(
        TABLE => 'CERTIFICATE',
        HASH  => \%insert_hash,
    );
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
