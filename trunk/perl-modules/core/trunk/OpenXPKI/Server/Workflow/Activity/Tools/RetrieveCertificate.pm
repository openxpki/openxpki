# OpenXPKI::Server::Workflow::Activity::Tools::RetrieveCertificate
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::RetrieveCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use DateTime;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

my @parameters = qw( 
    cert_profile 
    cert_email 
    cert_subject 
    min_remaining_validity
    valid_at
);

__PACKAGE__->mk_accessors(@parameters);

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $dbi         = CTX('dbi_backend');
    my $pki_realm   = CTX('session')->get_pki_realm();
    my $context    = $workflow->context();

    ##! 16: 'RetrieveCertificate'
    my %contextentry_of = (
	certificateout => 'certificate',
	certidentifierout  => undef,
	);
    foreach my $contextkey (keys %contextentry_of) {
	if (defined $self->param($contextkey . 'contextkey')) {
	    $contextentry_of{$contextkey} = $self->param($contextkey . 'contextkey');
	}
    }


    # propagate workflow activity parametrisation to our object
    foreach my $arg (@parameters) {
	if (defined $self->param($arg)) {
	    $self->$arg( $self->param($arg) );
	}
	# access worklow context instead of literal value if value starts
	# with a $
	if (defined $self->$arg() && ($self->$arg() =~ m{ \A \$ (.*) }xms)) {
	    my $wf_key = $1;
	    $self->$arg( $context->param($wf_key) )
	}
	##! 64: 'param: ' . $arg . '; value: ' . $self->$arg()
    }


    my %conditions = (
	);

    if (defined $self->cert_email()) {
	$conditions{'CERTIFICATE.EMAIL'} = $self->cert_email();
    }
    if (defined $self->cert_profile()) {
	$conditions{'CSR.PROFILE'} = $self->cert_profile();
    }
    if (defined $self->cert_subject()) {
	$conditions{'CERTIFICATE.SUBJECT'} = $self->cert_subject();
    }

    if (scalar keys(%conditions) == 0) {
	##! 16: 'operation mode 1 (search for certificate identifier)'
	my $cert_identifier = $context->param('cert_identifier');
	
	if (! defined $cert_identifier) {
	    ##! 16: 'no certificate identifier specified, clearing context entry'
	    $context->param($contextentry_of{'certificateout'} => undef);
	    return 1;
	}
	
	##! 16: 'searching for certificate identifier ' . $cert_identifier
	my $cert = $dbi->first(
	    TABLE   => 'CERTIFICATE',
	    COLUMNS => [
		'DATA',
	    ],
	    DYNAMIC => {
		'IDENTIFIER' => $cert_identifier,
		'STATUS'    => 'ISSUED',
		'PKI_REALM' => $pki_realm,
	    },
	    );
	
	$context->param($contextentry_of{'certificateout'} => $cert->{DATA});

	return 1;
    } else {
	##! 16: 'operation mode 2 (query certificate details)'
	my @validity;

	if (defined $self->valid_at()) {
	    if ($self->valid_at() =~ m{ \A (\d{4})(\d{2})(\d{2}) \z }xms) {
		my $dt = DateTime->new(year     => $1,
				       month    => $2,
				       day      => $3,
				       time_zone => 'UTC');
		push @validity, $dt->epoch;
	    } elsif ($self->valid_at() =~ m{ \A \d+ \z }xms) {
		push @validity, $self->valid_at();
	    } else {
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_RETRIEVECERTIFICATE_INVALID_TIME_SPECIFICATION',
		    params  => {
			valid_at => $self->valid_at(),
		    },
		    );
	    }
	}
	if (defined $self->min_remaining_validity()) {
	    push @validity, time + ($self->min_remaining_validity() * 24 * 3600);
	}
	if (scalar (@validity) == 0) {
	    push @validity, time;
	}

	my $certs = CTX('dbi_backend')->select(
	    TABLE   => [ 'CERTIFICATE', 'CSR' ],
	    COLUMNS => [
		'CERTIFICATE.DATA',
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
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_RETRIEVECERTIFICATE_QUERY_ERROR',
		params  => {
		},
		);
	}
	##! 16: 'found ' . scalar @{$certs} . ' matching certificates'
	if (scalar @{$certs} == 0) {
	    ##! 16: 'no matching certs found'
	    $context->param($contextentry_of{'certificateout'} => undef);
	    if (defined $contextentry_of{'certidentifierout'}) {
		$context->param($contextentry_of{'certidentifierout'} => undef);
	    }
	    return 1;
	}
	
	$context->param($contextentry_of{'certificateout'} => $certs->[0]->{'CERTIFICATE.DATA'});
	if (defined $contextentry_of{'certidentifierout'}) {
	    $context->param($contextentry_of{'certidentifierout'} => $certs->[0]->{'CERTIFICATE.IDENTIFIER'});
	}
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::RetrieveCertificate

=head1 Description

Searches certificate database for certificate with the matching criteria.

Activity configuration:
certificateoutcontextkey        context parameter to use for output certificate
                                (default: certificate)
certidentifieroutcontextkey     context parameter to use for output certificate
                                identifier
                                (default: none, do not write to context)


Operation mode 1: search for certificate identifier

If no activity options are specified this activity expects to find the
a context parameter cert_identifier. Its value is used to query the
database and search the corresponding certificate.

Sets context parameter 'certificate' to PEM encoded certificate with the
matching certificate identifier.


Operation mode 2: search for particular certificate with specified criteria

This operation mode is enabled if at least one of the following
activity parameters are defined in the activity definition. The
parameter cert_identifier is IGNORED if any of these parameters are
defined.

cert_profile:           filter certificates with this profile (required)
cert_email:             filter certificates with specified email address
cert_subject:           filter certificates with specified subject
min_remaining_validity: filter certificates with a minimum of the specified
                        number of days remaining before expiration
valid_at:               filter certificates which are valid at specified
                        time (allowed: Unix timestamp or YYYYMMDD, 
                        distinguished by value length)

Note: if parameters specified start with a '$', the corresponding workflow
context parameter is referenced instead of the literal string.

The first certificate with the matching criteria is exported via the
context parameter 'certificate' (PEM encoded).

Only if explicitly set in the activity configuration via 
identifieroutcontextkey the specified context entry is set by the 
activity to contain the retrieved certificate identifier.
