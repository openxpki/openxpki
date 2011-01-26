# OpenXPKI::Server::Workflow::Condition::CheckExistingCertificate
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::CheckExistingCertificate;

use strict;
use warnings;
use base qw( Workflow::Condition );
use DateTime;
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Exception;
use Data::Dumper;


my @parameters = qw( 
    cert_profile 
    cert_email 
    cert_subject 
    min_remaining_validity
    expected_cert_identifiers
    export_notafter
);

__PACKAGE__->mk_accessors(@parameters);

sub _init
{
    my ( $self, $params ) = @_;

    my $condition_available;
    # propagate workflow condition parametrisation to our object
    foreach my $arg (@parameters) {
	if (defined $params->{$arg}) {
	    $self->$arg( $params->{$arg} );
	    $condition_available = 1;
	}
    }
    if (! $condition_available) {
	##! 16: 'error: no conditions defined'
	configuration_error
	    "You must define at least one condition in ",
	    "declaration of condition ", $self->name;
    }
}

sub evaluate
{
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context     = $workflow->context();
    my $pki_realm   = CTX('session')->get_pki_realm();

    foreach my $arg (@parameters) {
	# access worklow context instead of literal value if value starts
	# with a $
	if (defined $self->$arg() && ($self->$arg() =~ m{ \A \$ (.*) }xms)) {
	    my $wf_key = $1;
	    $self->$arg( $context->param($wf_key) )
	}
	##! 64: 'param: ' . $arg . '; value: ' . $self->$arg()
    }

    my $expected_cert_identifiers;
    if (defined $self->expected_cert_identifiers()) {
	my $ser  = OpenXPKI::Serialization::Simple->new ();
	$expected_cert_identifiers = $ser->deserialize($self->expected_cert_identifiers());
	##! 64: 'check for expected cert identifiers: ' . Dumper $expected_cert_identifiers
    }

    CTX('dbi_backend')->commit();

    my %conditions = (
	);
    

    if (defined $self->cert_email()) {
	$conditions{'CERTIFICATE.EMAIL'} = $self->cert_email(),
    }
    if (defined $self->cert_profile()) {
	$conditions{'CSR.PROFILE'} = $self->cert_profile(),
    }
    if (defined $self->cert_subject()) {
	$conditions{'CERTIFICATE.SUBJECT'} = $self->cert_subject(),
    }


    my @validity = ( time );
    if (defined $self->min_remaining_validity()) {
	push @validity, time + ($self->min_remaining_validity() * 24 * 3600);
    }

    my $certs = CTX('dbi_backend')->select(
	TABLE   => [ 'CERTIFICATE', 'CSR' ],
	COLUMNS => [
	    'CERTIFICATE.IDENTIFIER',
	    'CERTIFICATE.NOTAFTER',
	],
	JOIN => [
	    [ 'CSR_SERIAL', 'CSR_SERIAL' ],
	],
	DYNAMIC => {
	    'CERTIFICATE.PKI_REALM'  => $pki_realm,
	    'CERTIFICATE.STATUS'     => 'ISSUED',
	    %conditions,
	},
	VALID_AT => [ [ @validity ], undef ],
	REVERSE => 1,
	);
    
    ##! 16: 'certificates found: ' . Dumper $certs
    if (! defined $certs) {
	##! 16: 'error: could not execute database query'
	condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKEXISTINGCERTIFICATE_QUERY_ERROR';
    }
    ##! 16: 'found ' . scalar @{$certs} . ' matching certificates'
    if (scalar @{$certs} == 0) {
	##! 16: 'error: no matching certs found'
	condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKEXISTINGCERTIFICATE_NO_MATCHING_CERTS_FOUND';
    }
    
    my $identifier = $certs->[0]->{'CERTIFICATE.IDENTIFIER'};
    ##! 16: 'latest certificate identifier: ' . $identifier

    if (defined $expected_cert_identifiers) {
	if (scalar @{$expected_cert_identifiers} == 0) {
	    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKEXISTINGCERTIFICATE_NO_EXISTING_CERTS_TO_CHECK';
	}
	# check if the latest identifier is one of the expected ones
	if (! grep(m{ \A $identifier \z }xms, @{$expected_cert_identifiers})) {
	    ##! 16: 'error: specified identifier ' . 
	    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKEXISTINGCERTIFICATE_CERT_ID_NOT_EXPECTED';
	}
    }    

    ##! 16: 'checks passed'
    $context->param('cert_identifier' => $identifier);

    if (defined $self->export_notafter()) {
	my $notafter_epoch = $certs->[0]->{'CERTIFICATE.NOTAFTER'};
	my $dt = DateTime->from_epoch(epoch => $notafter_epoch);

	my $notafter_absolute = OpenXPKI::DateTime::convert_date(
	    {
		DATE => $dt,
		OUTFORMAT => 'terse',
	    });
	##! 16: 'exporting notafter date ' . $notafter_absolute . ' to context entry ' . $self->export_notafter()
	$context->param($self->export_notafter() => $notafter_absolute);
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CheckExistingCertificate

=head1 SYNOPSIS
  <condition 
     name="usable_encryption_certificate_already_exists" 
     class="OpenXPKI::Server::Workflow::Condition::CheckExistingCertificate">
    <param name="cert_profile" value="I18N_OPENXPKI_PROFILE_USER_FSE"/>
    <param name="cert_email" value="$creator"/>
    <!-- minimum number of days until expiration -->
    <param name="min_remaining_validity" value="90"/>
  </condition>

=head1 DESCRIPTION

First operation mode: condition parameter 'expected_cert_identifiers' is not
set. The condition checks if there is at least one valid certificate with
the specified search criteria.
Returns a success if at least one matching certificate was found.

Second operation mode:
If the parameter 'expected_cert_identifiers' is set, its content is 
deserialized. The resulting array is interpreted as a list certificate
identifiers. The remaining parameters are used for a database search just
as in the first operation mode.
The newest match (highest NotAfter date) is checked against the list of
'expected_cert_identifiers'. If the match is found in the list the condition
returns success.
If the 'expected_cert_identifiers' array is empty, the condition always
fails.

Side effect on success: figures out the newest matching certificate 
and sets the workflow context parameter 'cert_identifier' 
to its certificate identifier.
Side effect on success: if 'export_notafter' is set in the activity
definition, the found NotAfter date is exported to the workflow context
entry specified via 'export_notafter' in YYYYMMDDHHMMSS format.


Parameters:

cert_profile:           filter certificates with this profile
cert_email:             filter certificates with specified email address
cert_subject:           filter certificates with specified subject
min_remaining_validity: filter certificates with a minimum of the specified
                        number of days remaining before expiration

expected_cert_identifiers: presence enables second operation mode (see
                           above. interpreted as serialized array of
                           certificate identifiers to match against
                           query results.
export_notafter         if defined, the notafter date of the certificate
                        is written to the specified context entry

Note: if parameters specified start with a '$', the corresponding workflow
context parameter is referenced instead of the literal string.

