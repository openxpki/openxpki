# OpenXPKI::Server::Workflow::Activity::Tools::ParseCertificate
# Written by Martin Bartosch for the OpenXPKI project 2011
# Copyright (c) 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::ParseCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

my @parameters = qw( 
    cert_attrmap
    certificate
);

__PACKAGE__->mk_accessors(@parameters);


sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $dbi         = CTX('dbi_backend');
    my $default_token = CTX('pki_realm_by_cfg')->
                           {$self->config_id()}->
                           {$self->{PKI_REALM}}->{crypto}->{default};

    ##! 16: 'ParseCert'
    my %contextentry_of = (
	certificatein => 'certificate',
	);
    foreach my $contextkey (keys %contextentry_of) {
	if (defined $self->param($contextkey . 'contextkey')) {
	    $contextentry_of{$contextkey} = $self->param($contextkey . 'contextkey');
	}
    }

    my %cert_attrmap = map { split(/\s*[=-]>\s*/) }
        split( /\s*,\s*/, $self->param('cert_attrmap') );
    
    
    my $certificate = $context->param($contextentry_of{'certificatein'});

    my $x509 = OpenXPKI::Crypto::X509->new(
	TOKEN => $default_token,
	DATA  => $certificate,
	);

    my $x509_parsed = $x509->get_parsed_ref();

    foreach my $key (keys %cert_attrmap) {
	if (! exists $x509_parsed->{BODY}->{$key}) {
	    OpenXPKI::Exception->throw(
		message =>
		'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PARSE_CERT_INVALID_ATTRIBUTE',
		params => {
		    ATTRIBUTE => $key,
		},
		log => {
		    logger   => CTX('log'),
		    priority => 'error',
		    facility => 'system',
		},
		);
	}
	my $value = $x509_parsed->{BODY}->{$key};
	
	if (ref $value ne '') {
	    OpenXPKI::Exception->throw(
		message =>
		'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PARSE_CERT_INVALID_ATTRIBUTE_DATA_TYPE',
		params => {
		    ATTRIBUTE => $key,
		    TYPE      => ref $value,
		},
		log => {
		    logger   => CTX('log'),
		    priority => 'error',
		    facility => 'system',
		},
		);
	}

	my $context_key = $cert_attrmap{$key};

	$context->param($context_key => $value);
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ParseCertificate

=head1 Description

Parse certificate and populate context entries with parsed information
from the certificate.

=head1 Parameters

=head2 cert_attrmap

Map parsed certificate attributes to context parameter names, allowing 
flexible access and assignment of data parsed certificates into the context. 
Must be defined, otherwise no output is generated in the context. Mapping
keys must be specified correctly (including case), otherwise an exception
is thrown.

List of (useful) mapping keys, the available values are identical to
the entries in the X.509 class member variable $cert->{PARSED}->{BODY}.
Some of these entries are not scalar values, but complex types. These
are currently not available and referencing them cause an exception to
be thrown.

    SUBJECT
    SERIAL
    SERIAL_HEX
    IS_CA
    ISSUER
    EMAILADDRESS

Less useful, but still available:

    PUBKEY_ALGORITHM
    SIGNATURE_ALGORITHM
    CA_KEYID
    EXPONENT           (hexadecimal string)
    FINGERPRINT
    KEYID
    KEYSIZE
    MODULUS            (hexadecimal string)
    OPENSSL_SUBJECT
    PLAIN_EXTENSIONS   (large text blob, unstructured)
    VERSION


Example for cert_attrmap:

SUBJECT -> cert_subject, ISSUER -> cert_issuer

Writes the certificate subject to the context entry 'cert_subject', the
certificate issuer to 'cert_issuer'.


=head2 certificateincontextkey

Context parameter to use for input certificate (default: certificate)

