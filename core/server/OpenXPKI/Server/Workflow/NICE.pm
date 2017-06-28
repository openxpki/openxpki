## OpenXPKI::Server::Workflow::NICE.pm
## Base Class for NICE Backends
##
## Written 2011 by Oliver Welter <openxpki@oliwel.de>
## for the OpenXPKI project
## (C) Copyright 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::NICE;

use strict;
use warnings;
use English;

use Data::Dumper;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Database::Legacy;
use OpenXPKI::Server::Database; # to get AUTO_ID
use Moose;
#use namespace::autoclean; # Comnflicts with Debugger

# Attribute Setup

has 'activity' => (
    is  => 'ro',
    isa => 'Object|Undef',
    reader => '_get_activity',
);


has 'workflow' => (
    is  => 'ro',
    isa => 'Workflow',
    reader => '_get_workflow',
    builder => '_init_workflow',
    lazy => 1,
);

has 'context' => (
    is  => 'ro',
    isa => 'Workflow::Context',
    reader => '_get_context',
    builder => '_init_context',
    lazy => 1,
);

# Moose pre-constuctor to map single argument activity into expected hashref

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    return $class->$orig( activity => $_[0] );

};


sub _init_workflow {
    my $self = shift;
    my $activity = $self->_get_activity;
    return undef unless ($activity);
    return $activity->workflow();
}

sub _init_context {
    my $self = shift;
    return $self->_get_workflow->context();
}

sub _get_context_param {
    my ($self , $context_parameter_name) = @_;
    return $self->_get_context()->param( $context_parameter_name );
}

sub _set_context_param {
    my ($self , $context_parameter_name, $set_to_value) = @_;
    return $self->_get_context()->param( $context_parameter_name, $set_to_value );
}

sub __context_param {
    my ($self , $attrib_map, $context_parameter_name, $set_to_value) = @_;

    # Lookup map if there is a mapping
    my $real_parameter_name = $attrib_map->{$context_parameter_name};
    $real_parameter_name = $context_parameter_name unless( $real_parameter_name );

    if (defined $set_to_value) {
        return $self->_get_context()->param( $real_parameter_name, $set_to_value );
    } else {
        return $self->_get_context()->param( $real_parameter_name );
    }
}

# Put Information into the DataPool and write certificate table
sub __persistCertificateInformation {
    my ($self, $cert_info, $persist_data) = @_;
    ##! 64: 'certificate information: ' . Dumper ( $cert_info )

    my $pki_realm = CTX('api')->get_pki_realm();
    my $default_token = CTX('api')->get_default_token();

    my $x509 = OpenXPKI::Crypto::X509->new(
        TOKEN => $default_token,
        DATA  => $cert_info->{certificate},
    );

    # FIXME #legacydb Migrate OpenXPKI::Crypto::X509->to_db_hash() later on
    my $cert_data = OpenXPKI::Server::Database::Legacy->certificate_from_legacy({ $x509->to_db_hash });
    my $identifier = $cert_data->{identifier};

    my $serializer = OpenXPKI::Serialization::Simple->new();

    if ($persist_data) {
        my $serialized_data = $serializer->serialize( $persist_data );
        ##! 16: 'Persist certificate: ' . $identifier
        ##! 32: 'persisted data: ' . Dumper( $persist_data )
        CTX('api')->set_data_pool_entry({
            PKI_REALM => $pki_realm,
            NAMESPACE => 'nice.certificate.information',
            KEY       => $identifier,
            VALUE     => $serialized_data,
            ENCRYPT   => 0,
            FORCE     => 1,
        });
    }

    # Try to autodetected the ca_identifier ....
    my $ca_id = $cert_info->{ca_identifier};
    if (not $ca_id) {
        my $issuer = CTX('dbi')->select_one(
            from => 'certificate',
            columns => [ 'identifier' ],
            where => {
                $cert_data->{authority_key_identifier}
                    ? (subject_key_identifier => $cert_data->{authority_key_identifier})
                    : (subject => $cert_data->{issuer_dn}),
                status    => 'ISSUED',
                pki_realm => [ $pki_realm, undef ],
            },
        );
        ##! 32: 'returned issuer ' . Dumper( $issuer )
        if ($issuer->{identifier}) {
            $ca_id = $issuer->{identifier};
        } else {
            $ca_id = 'unknown';
            CTX('log')->application()->warn("NICE certificate issued with unknown issuer! ($identifier / ".$cert_data->{issuer_dn}.")");


        }
    }

    CTX('log')->audit('cakey')->info('certificate signed', {
        cakey     => $cert_data->{authority_key_identifier},
        certid    => $identifier,
        key       => $cert_data->{subject_key_identifier},
        pki_realm => $pki_realm,
    });

    CTX('log')->audit('entity')->info('certificate issued', {
        certid    => $identifier,
        key       => $cert_data->{subject_key_identifier},
        pki_realm => $pki_realm,
    });


    CTX('dbi')->insert(
        into => 'certificate',
        values=> {
            %$cert_data,
            issuer_identifier => $ca_id,
            pki_realm         => $pki_realm,
            req_key           => $cert_info->{csr_serial},
            status            => 'ISSUED',
        },
    );


    my @parsed_subject_alt_names = $x509->get_subject_alt_names();
    ##! 32: 'sans (parsed): ' . Dumper \@parsed_subject_alt_names
    for my $san (@parsed_subject_alt_names) {
        CTX('dbi')->insert(
            into => 'certificate_attributes',
            values => {
                attribute_key        => AUTO_ID,
                identifier           => $identifier,
                attribute_contentkey => 'subject_alt_name',
                attribute_value      => join(":", @$san),
            },
        );
    }

    # if this originates from a workflow, register the workflow id in the attribute table
    if ($self->_get_workflow()) {
        CTX('dbi')->insert(
            into => 'certificate_attributes',
            values => {
                attribute_key        => AUTO_ID,
                identifier           => $identifier,
                attribute_contentkey => 'system_workflow_csr',
                attribute_value      => $self->_get_workflow()->id,
            }
        );
    }
    return $identifier;
}

sub __fetchPersistedCertificateInformation {

    my $self = shift;
    my $certificate_identifier = shift;

    my $pki_realm = CTX('api')->get_pki_realm();

    my $serialized_data = CTX('api')->get_data_pool_entry({
        PKI_REALM => $pki_realm,
        NAMESPACE => 'nice.certificate.information',
        KEY => $certificate_identifier,
      });

      my $serializer = OpenXPKI::Serialization::Simple->new();

    return $serializer->deserialize( $serialized_data->{VALUE} );

}

sub issueCertificate {

    OpenXPKI::Exception->throw(
          message => "I18N_OPENXPKI_SERVER_NICE_NOT_IMPLEMENTED_ERROR",
          params => { sub => (caller(0))[3] }
    );
}

sub renewCertificate {

    OpenXPKI::Exception->throw(
          message => "I18N_OPENXPKI_SERVER_NICE_NOT_IMPLEMENTED_ERROR",
          params => { sub => (caller(0))[3] }
    );

}

sub fetchCertificate {

    OpenXPKI::Exception->throw(
          message => "I18N_OPENXPKI_SERVER_NICE_NOT_IMPLEMENTED_ERROR",
          params => { sub => (caller(0))[3] }
    );

}

sub revokeCertificate {

    OpenXPKI::Exception->throw(
          message => "I18N_OPENXPKI_SERVER_NICE_NOT_IMPLEMENTED_ERROR",
          params => { sub => (caller(0))[3] }
    );

}

sub unrevokeCertificate {

    OpenXPKI::Exception->throw(
          message => "I18N_OPENXPKI_SERVER_NICE_NOT_IMPLEMENTED_ERROR",
          params => { sub => (caller(0))[3] }
    );

}

sub checkForRevocation {

    OpenXPKI::Exception->throw(
          message => "I18N_OPENXPKI_SERVER_NICE_NOT_IMPLEMENTED_ERROR",
          params => { sub => (caller(0))[3] }
    );
}

sub issueCRL {

    OpenXPKI::Exception->throw(
          message => "I18N_OPENXPKI_SERVER_NICE_NOT_IMPLEMENTED_ERROR",
          params => { sub => (caller(0))[3] }
    );
}

sub fetchCRL {

    OpenXPKI::Exception->throw(
          message => "I18N_OPENXPKI_SERVER_NICE_NOT_IMPLEMENTED_ERROR",
          params => { sub => (caller(0))[3] }
    );
}



# Speeds up Moose
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::NICE

=head1 Description

NICE ist the Nice Interface for Certificate Enrollment.
This class is just a stub to be inherited by your specialised backend class.

The mandatory input parameters are directly passed to the methods while the
mandatory return values should be returned as a hash ref by the method call
and are written to the context by the surrounding activity functions.
The implementations are free to access the context to transport internal
parameters.

=head1 API Functions

=head2 issueCertificate

Submit a certificate request for a new certificate. The certificate request
entry from the database is passed in as hashref.

Note that it highly depends on the implementation what properties are taken from
the pkcs10 container and what can be overridden by other means.
PKCS10 is the default format which should be supported by any backend, the
default local backend also supports SPKAC. You might implement any own format.
See documentation of the used backend for details.

=head3 Input

=over

=item csr - hashref containing the database entry from the csr table

=back

=head3 Output

=over

=item cert_identifier - the identifier of the issued certificate or I<pending>

=back

=head3 csr attributes

Besides the properties of the csr, following attributes should be processed
where applicable.

=over

=item I<custom_requester_{name|gname|email}> - information about
the requester

=item I<cert_subject_alt_name> - Nested Array with attributes for SAN section

=item I<notbefore|notafter> - special validity

=back


=head2 renewCertificate

Submit a certificate renewal request. Same as issueCertificate but
receives the certificate identifier of the originating certificate as
second parameter.

=head3 Input

=over

=item csr - hashref containing the database entry from the csr table

=item cert_identifier - identifier of the originating certificate

=back

=head3 Output

=over

=item cert_identifier - the identifier of the issued certificate or I<pending>

=back

=head2 fetchCertificate

This is only valid if issueCertificate or renewCertificate returned with a
pending request and tries to fetch the requested certificate. If successful,
the cert_identifier context parameter is populated with the identifier,
otherwise the pending marker remains in the context.
If the fetch finally failed, it should unset the cert_identifier.

=head3 Output

=over

=item cert_identifier - the identifier of the issued certificate

=back

=head2 revokeCertificate

Request the ca to add this certificate to its revocation list. Expects the
serial of the certificate revocation request.  If the given reason is not
supported by the backend, "unspecified" should be used.

=head3 Input

=over

=item crr_serial - the serial number of the certificate revocation request

=back

=head2 checkForRevocation

Only valid after calling revokeCertificate.
Check if the certificate revocation request was processed and set the status
field in the certificate table to REVOKED/HOLD. The special state HOLD must
be used only if the certificate is marked as "certificateHold" on the issued
CRL or OCSP.

=head3 Input

=over

=item cert_identifier

=back

=head2 unrevokeCertificate

Remove a formerly revoked certifiate from the revocation list. Expects
the certificate identifier. Only allowed after "certificateHold", sets the
status field of the certificate status table back to ISSUED immediately.

=head3 Input

=over

=item cert_identifier

=back

=head2 issueCRL

Trigger issue of the crl and write it into the "crl" parameter.
The parameter ca_alias contains the alias name of the ca token.

=head3 Input

=over

=item ca_alias

=back

=head3 Output

=over

=item crl_serial - the serial number (key of the crl database) of the created
crl or I<pending>

=back

=head2 fetchCRL

Only valid after calling issueCRL, tries to fetch the new CRL.
See issue/fetchCertificate how to use the pending marker.


=head1 internal helper functions

=head2 _get_context_param

Expect the name of the context field as parameter and returns the appropriate
context value. Does B<not> deserialize the content.

=head2 _set_context_param

Expect the name of the context field, and its new value.
 Does B<not> serialize the content.

=head2 __persistCertificateInformation

Persist a certificate into the certificate table and store implementation
specific information in the datapool. The first parameter is mandatory with
all fields given below. The second parameter is serialized "as is" and stored
in the datapool and can be retrieved later using C<__fetchPersistedCertificateInformation>.

=head3 certificate_information

=over

=item certificate - the PEM encoded certificate

=item ca_identifier - the identifier of the issuing ca

=item csr_serial - serial number of the processed csr

=back

The certificate is expected to be a x509 structure. A pkcs7 container with
the entity certificate and its chain is also accepted.

If the ca_identifier is not set, we try to autodetect it by searching the
certificate table for a certificate which matches the authority key identifier.
If the certificate has no authority key identifier set, the lookup is done on
the the issuer dn.

=head2 __fetchPersistedCertificateInformation

Return the hashref for a given certificate identifiere stored within the
datapool using C<__persistCertificateInformation>.


=head1 Implementors Guide

The NICE API implements every operation in two individual steps to support
asynchronus operating backends. If you are building a synchronus backend, you
can ommit the implementation of the second steps.

The activity definitions in OpenXPKI::Server::Workflow::Activity::NICE::*
show the expected usage of the API functions.

=head1 issue/renew Certificate

The request information must be taken from the csr and csr_attributes t

The method must persist the certificate by calling __persistCertificateInformation
and write the certificates identifier into the context parameter cert_identifier.

If the request was dispatched but is still pending, the  must
be written into the cert_identifier context value. If cert_identifier is not set
after execution, the workflow will call this method again.

