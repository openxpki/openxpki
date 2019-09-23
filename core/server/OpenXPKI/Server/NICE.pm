package OpenXPKI::Server::NICE;

use strict;
use warnings;
use English;

use Data::Dumper;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypt::X509;
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

has 'last_error' => (
    is => 'rw',
    isa => 'Str',
    reader => 'get_last_error',
    lazy => 1,
    default => '',
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

    my $pki_realm = CTX('api2')->get_pki_realm();
    my $default_token = CTX('api2')->get_default_token();

    my $x509 = OpenXPKI::Crypt::X509->new( $cert_info->{certificate} );

    my $cert_data = $x509 ->db_hash();
    my $identifier = $cert_data->{identifier};

    my $serializer = OpenXPKI::Serialization::Simple->new();

    if ($persist_data && (scalar keys %{$persist_data})) {
        my $serialized_data = $serializer->serialize( $persist_data );
        ##! 16: 'Persist certificate: ' . $identifier
        ##! 32: 'persisted data: ' . Dumper( $persist_data )
        CTX('api2')->set_data_pool_entry(
            pki_realm => $pki_realm,
            namespace => 'nice.certificate.information',
            key       => $identifier,
            value     => $serialized_data,
            encrypt   => 0,
            force     => 1,
        );
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


    my @parsed_subject_alt_names = @{$x509->get_subject_alt_name()};
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

    my $pki_realm = CTX('api2')->get_pki_realm();

    my $serialized_data = CTX('api2')->get_data_pool_entry(
        pki_realm => $pki_realm,
        namespace => 'nice.certificate.information',
        key => $certificate_identifier,
    );

    my $serializer = OpenXPKI::Serialization::Simple->new();

    return $serializer->deserialize( $serialized_data->{value} );

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

sub generateKey {

    OpenXPKI::Exception->throw(
          message => "I18N_OPENXPKI_SERVER_NICE_NOT_IMPLEMENTED_ERROR",
          params => { sub => (caller(0))[3] }
    );

}

sub fetchKey {

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

OpenXPKI::Server::NICE

=head1 Description

NICE ist the Nice Interface for Certificate Enrollment.
This class is just a stub to be inherited by your specialised backend class.

The mandatory input parameters are directly passed to the methods while the
mandatory return values should be returned as a hash ref by the method call
and are written to the context by the surrounding activity functions.
The implementations are free to access the context to transport internal
parameters.

If the expected operation could not be completed, the method MUST return
undef, it is recommended to set a verbose error in the I<last_error> class
attribute (this might also show up on the UI).

The methods should NOT use workflow controls as pause or retry, this should
be left to the activity classes. Methods should throw exceptions only on
final errors (such that will not succeed when called again with the same
input data).

=head1 API Functions

=head2 issueCertificate

Submit a certificate request for a new certificate. The certificate request
entry from the database is passed in as hashref.

Note that it highly depends on the implementation what properties are taken
from the pkcs10 container and what can be overridden by other means.
PKCS10 is the default format which should be supported by any backend.
You might implement any own format.
See documentation of the used backend for details.

In case the backend has processed the request but needs extra time to
process it, the response should be a hash with cert_identifier set to
undef. The backend should support pickup of the certificate by fetch
certificate in this case and keep information in the context to process
this call.

=head3 Parameters

=over

=item csr - hashref containing the database entry from the csr table

=item ca_alias - name of the ca-token to use

=back

=head3 Return values

=over

=item cert_identifier - the identifier of the issued certificate

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
serial of the certificate revocation request. If the given reason is not
supported by the backend, "unspecified" should be used.

=head3 Parameters

=over

=item cert_identifier - the certificate identifier of the cert to revoke

=item reason_code

=item invalidity_time

=back

=head3 Return Values

Boolean, true if the request was processed. Should throw an exception if
revocation is not possible.

=head2 checkForRevocation

Might only valid after calling revokeCertificate.

Check if the certificate revocation request was processed and set the status
field in the certificate table to REVOKED/HOLD. The special state HOLD must
be used only if the certificate is marked as "certificateHold" on the issued
CRL or OCSP.

=head3 Parameters

=over

=item cert_identifier

=back

=head3 Return Values

true if the certificate is revoked, false if not.

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

In case the backend has processed the request but needs extra time to
process it, the response should be a hash with csr_serial set to
undef. The backend should support pickup of the certificate by fetchCrl
in this case and keep information in the context to process this call.

=head3 Parameters

=over

=item ca_alias

=back

=head3 Return values

=over

=item crl_serial - the serial number (key of the crl database)

=back

=head2 fetchCRL

Only valid after calling issueCRL, tries to fetch the new CRL.
See issue/fetchCertificate how to use the pending marker.

=head2 generateKey

Generate and return a private key according to the parameters passed.
Supported modes and parameter sets depend on the backend, some backends
might even not implement this method.

=head3 Input

=over

=item mode - can be used to switch between different modes, see backend

=item key_alg - name of the algorithm, as used in the profile definitions

=item key_params - key generation parameters, hash with pkey options

=item key_transport - hash with key I<password> and I<algorithm>, determines
settings for the used transport encryption

=back

=head3 Output

Return value is a hash, the encrypted key must be returned in the key I<pkey>.

Additional arguments might be returned by the backend.

=head2 fetchKey

Fetch a key created by with generateKey from the backend. Usage of the
password and key_transport settings might differ between implementations.

=head3 Input

=over

=item key_identifier - the identifier of the key

=item password - password / secret to fetch the key

=item key_transport - hash with key I<password> and I<algorithm>, determines settings for the used transport encryption

=back

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

