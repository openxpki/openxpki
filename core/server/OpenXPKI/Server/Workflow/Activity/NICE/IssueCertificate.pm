# OpenXPKI::Server::Workflow::Activity::NICE::IssueCertificate
# Written by Oliver Welter for the OpenXPKI Project 2011
# Copyright (c) 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::NICE::IssueCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use English;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Database::Legacy;

use OpenXPKI::Server::NICE::Factory;
use OpenXPKI::Server::Database; # to get AUTO_ID

use Data::Dumper;

sub execute {

    my ($self, $workflow) = @_;
    my $context = $workflow->context();
    ##! 32: 'context: ' . Dumper( $context )

    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );

    # Load the CSR indicated by the activity or context parameter from the database
    my $csr_serial = $self->param( 'csr_serial' ) || $context->param( 'csr_serial' );

    ##! 32: 'load csr from db: ' . $csr_serial
    my $csr = CTX('dbi')->select_one(
        from => 'csr',
        columns => [ '*' ],
        where => {
            req_key => $csr_serial,
            pki_realm => CTX('session')->data->pki_realm,
        },
    );

    ##! 64: 'csr: ' . Dumper $csr
    if (! defined $csr) {
       OpenXPKI::Exception->throw(
           message => 'I18N_OPENXPKI_SERVER_NICE_CSR_NOT_FOUND_IN_DATABASE',
           params => { csr_serial => $csr_serial }
       );
    }

    my $ca_alias = $self->param( 'ca_alias' ) || '';

    if ($csr->{format} ne 'pkcs10' && $csr->{format} ne 'spkac') {
       OpenXPKI::Exception->throw(
           message => 'I18N_OPENXPKI_SERVER_NICE_CSR_WRONG_TYPE',
           params => { EXPECTED => 'pkcs10/spkac', TYPE => $csr->{format} },
        );
    }

    CTX('log')->application()->info("start cert issue for serial $csr_serial, workflow " . $workflow->id);

    my $param = $self->param();
    delete $param->{'csr_serial'};
    delete $param->{'ca_alias'};

    my $set_context;
    eval {
        if ($param->{renewal_cert_identifier}) {
            $set_context = $nice_backend->renewCertificate( $csr, $ca_alias, $param);
        } else {
            $set_context = $nice_backend->issueCertificate( $csr, $ca_alias, $param );
        }
    };

    my $error;
    if ($EVAL_ERROR) {
        $error = 'I18N_OPENXPKI_UI_NICE_BACKEND_ERROR';
        CTX('log')->application()->error("NICE backend error: $EVAL_ERROR");
    } elsif(!$set_context) {
        $error = $nice_backend->get_last_error() || 'I18N_OPENXPKI_UI_NICE_BACKEND_ERROR';
    }

    if ($error) {
        # Catch exception as "pause" if configured
        if ($param->{pause_on_error}) {
            CTX('log')->application()->warn("NICE issueCertificate failed but pause_on_error is requested ");
            $self->pause($error);
        }

        if (my $exc = OpenXPKI::Exception->caught()) {
            $exc->rethrow();
        } else {
            OpenXPKI::Exception->throw( message => $error );
        }
    }

    ##! 64: 'Setting Context ' . Dumper $set_context
    for my $key (keys %{$set_context} ) {
        my $value = $set_context->{$key};
        ##! 64: "Set key: $key to value $value";
        $context->param( { $key => $value } );
    }

    ##! 64: 'Context after issue ' .  Dumper $context

    # some backends might not set the cert_identifier to handle
    # loops/polling. In this case we can not set the attributes
    if (!$set_context->{cert_identifier}) {
        CTX('log')->application()->info("NICE issueCertificate did not return cert_identifier yet");

    } else {

        # Record the certificate owner information, see
        # https://github.com/openxpki/openxpki/issues/183


        ##! 64: $param
        if ($param->{cert_owner}) {
            ##! 32: 'Owner ' . $param->{cert_owner}
            CTX('dbi')->insert(
                into => 'certificate_attributes',
                values => {
                    attribute_key => AUTO_ID,
                    identifier => $set_context->{cert_identifier},
                    attribute_contentkey => 'system_cert_owner',
                    attribute_value => $param->{cert_owner},
                },
            );
        }

        if ($param->{cert_tenant}) {
            ##! 32: 'Tenant ' . $param->{cert_tenant}
            CTX('dbi')->insert(
                into => 'certificate_attributes',
                values => {
                    attribute_key => AUTO_ID,
                    identifier => $set_context->{cert_identifier},
                    attribute_contentkey => 'system_cert_tenant',
                    attribute_value => $param->{cert_tenant},
                },
            );
        }

        if ($param->{renewal_cert_identifier}) {
            CTX('dbi')->insert(
                into => 'certificate_attributes',
                values => {
                    attribute_key => AUTO_ID,
                    identifier => $set_context->{cert_identifier},
                    attribute_contentkey => 'system_renewal_cert_identifier',
                    attribute_value => $param->{renewal_cert_identifier},
                },
            );
        }
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::IssueCertificate;

=head1 Description

Loads the certificate signing request referenced by the csr_serial context
parameter from the database and hands it to the configured NICE backend.

Note that it highly depends on the implementation what properties are taken from
the pkcs10 container and what can be overridden by other means.
The activity allows request types spkac and pkcs10 - you need to adjust this
if you use other formats.
See documentation of the used backend for details.

See OpenXPKI::Server::NICE::issueCertificate for details

=head1 Parameters

=head2 Input

=over

=item csr_serial (optional)

the serial number of the certificate signing request.
If not set the context value with key I<csr_serial> is used.

=item ca_alias (optional)

the ca alias to use for this signing operation, the default is to use
the "latest" token from the certsign group.
B<Might not be supported by all backends!>

=item transaction_id

Transaction id of the request, not required for the Local backend but
might be required by some remote backends to handle polling/retry.

=item renewal_cert_identifier

Set to the originating certificate identifier if this is a renewal request.
This will route the processing to the renewCertificate method of the NICE
backend and add the old certificate identifier as predecessor using the
certificate_attributes table (key I<system_renewal_cert_identifier>).

=item cert_owner

The userid that should be set as certificate owner (I<system_cert_owner>).

=item cert_tenant

The owner group / tenant for this certificate (I<system_cert_tenant>).

=back

=head2 Output

=over

=item cert_identifier - the identifier of the issued certificate. Not set
if the backend did not issue the certificate (also depends on error handling)

=back
