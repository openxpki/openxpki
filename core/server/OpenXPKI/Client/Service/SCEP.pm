package OpenXPKI::Client::Service::SCEP;
use OpenXPKI -class;

with 'OpenXPKI::Client::Service::Role::Base';

sub service_name { 'scep' } # required by OpenXPKI::Client::Service::Role::Base

# Core modules
use MIME::Base64;
use List::Util qw( any );

# Project modules
use OpenXPKI::Client::Service::Response;


has transaction_id => (
    is => 'ro',
    isa => 'Str',
    init_arg => undef,
    lazy => 1,
    default => sub { shift->attr->{transaction_id} },
);

has message_type => (
    is => 'ro',
    isa => 'Str',
    init_arg => undef,
    lazy => 1,
    default => sub { shift->attr->{message_type} },
);

has signer => (
    is => 'ro',
    isa => 'Str',
    init_arg => undef,
    lazy => 1,
    default => sub { shift->attr->{signer} || '' },
);

has attr => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    trigger => sub { die '"attr" can only be set once' if scalar @_ > 2 },
    predicate => 'has_attr',
);


# required by OpenXPKI::Client::Service::Role::Base
sub prepare ($self) {
    # set operation from request parameter
    $self->operation($self->request->url->query->param('operation') // '');
}

# required by OpenXPKI::Client::Service::Role::Base
sub send_response ($self, $response) {
    # HTTP header
    if ($self->config->{output}->{headers}) {
        $self->response->headers->add($_ => $response->extra_headers->{$_}) for keys $response->extra_headers->%*;
    }

    # Server errors are never encoded with PKCS7
    if ($response->is_server_error) {
        $self->disconnect_backend;
        $self->response->headers->content_type('text/plain');
        return $self->render(text => $response->error_message);

    # PKCS7 response (incl. client errors) - only after successful decoding of PKCS7 request
    } elsif ('PKIOperation' eq $self->operation and $self->has_attr) {
        my $out = $self->generate_pkcs7_response( $response );
        $self->disconnect_backend;
        $self->log->trace('PKCS7 response: ' . $out) if $self->log->is_trace;
        $out = decode_base64($out);

        $self->response->headers->content_type('application/x-pki-message');
        return $self->render(data => $out);

    # non-PKCS7 client errors
    } elsif ($response->is_client_error) {
        $self->disconnect_backend;
        $self->response->headers->content_type('text/plain');
        return $self->render(text => $response->error_message);

    } else {
        $self->disconnect_backend;
        $self->log->trace('Response: ' . $response->result) if $self->log->is_trace;

        if ('GetCACaps' eq $self->operation) {
            $self->response->headers->content_type('text/plain');
            return $self->render(text => $response->result);

        } elsif ('GetCACert' eq $self->operation) {
            $self->response->headers->content_type('application/x-x509-ca-ra-cert');
            return $self->render(data => decode_base64($response->result));

        } elsif ('GetNextCACert' eq $self->operation) {
            $self->response->headers->content_type('application/x-x509-next-ca-cert');
            return $self->render(data => decode_base64($response->result));
        }
    }

}

# required by OpenXPKI::Client::Service::Role::Base
sub op_handlers {
    return [
        'PKIOperation' => sub ($self) {
            my $message;
            # GET: read Base64 encoded message from URL parameter
            if ($self->request->method eq 'GET') {
                $message = $self->request->url->query->param('message');
                $self->log->debug("Got PKIOperation via GET");
            # POST: read message from request body
            } else {
                $message = encode_base64($self->request->body, '');
                if (not $message) {
                    $self->log->error("POSTDATA is empty - check documentation on required setup for Content-Type headers!");
                    $self->log->debug("Content-Type is: " . ($self->request->headers->content_type || 'undefined'));
                    return OpenXPKI::Client::Service::Response->new( 40003 );
                }
                $self->log->debug("Got PKIOperation via POST");

            }
            $self->log->trace("SCEP request: " . $message) if $self->log->is_trace;

            # Does a call to the backend to unwrap the SCEP message and returns
            # the payload and some attributes
            try {
                $self->set_pkcs7_message( $message );
            }
            # something is wrong, TODO we might try to branch request vs. server errors
            catch ($err) {
                $self->log->warn($err);
                return OpenXPKI::Client::Service::Response->new( 50010 );
            }

            $self->log->warn('Error while parsing PKCS7 message: ' . $self->attr->{error}) if $self->attr->{error};

            if (not $self->attr->{alias}) {
                $self->log->warn('Unable to find RA certificate');
                return OpenXPKI::Client::Service::Response->new ( 40002 );
            }

            if (not $self->signer) {
                $self->log->warn('Unable to extract signer certficate');
                return OpenXPKI::Client::Service::Response->new ( 40001 );
            }

            # Enrollment request
            if (any { $self->message_type eq $_ } qw( PKCSReq RenewalReq GetCertInitial )) {
                # TODO - improve handling of GetCertInitial and RenewalReq
                $self->log->debug("Handle enrollment");
                return $self->handle_enrollment_request;

            # Request for CRL or GetCert with IssuerSerial in Payload
            } elsif (any { $self->message_type eq $_ } qw( GetCert GetCRL )) {
                return $self->handle_property_request($self->message_type);

            } else {
                $self->log->warn(sprintf('Unknown message type "%s"', $self->message_type));
                return OpenXPKI::Client::Service::Response->new ( 40000 );
            }

        },
        [ 'GetCACaps', 'GetCACert', 'GetNextCACert' ] => \&handle_property_request,
    ];
}

# required by OpenXPKI::Client::Service::Role::Base
sub custom_wf_params ($self, $params) {
    # nothing special if we are NOT in PKIOperation mode
    return unless $self->operation eq 'PKIOperation';

    $self->log->debug("Adding extra parameters for message type '".$self->message_type."'");

    if ($self->message_type eq 'PKCSReq') {
        # This triggers the build of attr which triggers the unwrap call
        # against the server API and populates the class attributes
        $params->{pkcs10} = $self->attr->{pkcs10};
        $params->{transaction_id} = $self->transaction_id;
        $params->{signer_cert} = $self->signer;

        # Load url paramters if defined by config
        my $conf = $self->config->{'PKIOperation'};
        if ($conf->{param}) {
            my $extra;
            my @extra_params;
            # The legacy version - map anything
            if ($conf->{param} eq '*') {
                @extra_params = $self->request->params->names->@*;
            } else {
                @extra_params = split /\s*,\s*/, $conf->{param};
            }
            foreach my $param (@extra_params) {
                next if ($param eq "operation");
                next if ($param eq "message");
                $extra->{$param} = $self->request->param($param);
            }
            $params->{_url_params} = $extra;
        }

    } elsif ($self->message_type eq 'GetCertInitial') {
        $params->{transaction_id} = $self->transaction_id;
        $params->{signer_cert} = $self->signer;

    } elsif ($self->message_type =~ m{\AGet(Cert|CRL)\z}) {
        $params->{issuer} = $self->attr->{issuer_serial}->{issuer};
        $params->{serial} = $self->attr->{issuer_serial}->{serial};
    }
}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare_enrollment_result ($self, $workflow) {
    return OpenXPKI::Client::Service::Response->new(
        workflow => $workflow,
        result => $workflow->{context}->{cert_identifier},
    );
}

sub set_pkcs7_message ($self, $pkcs7) {
    die "PKCS7 message is not set or empty" unless $pkcs7;

    my $attrs = {};
    try {
        $attrs = $self->backend->run_command('scep_unwrap_message' => { message => $pkcs7 });
    }
    catch ($err) {
        $self->log->error("$err"); # stringification
        die "Unable to unwrap PKCS7 message";
    }

    $self->log->trace("Unwrapped PKCS7 message: " . Dumper $attrs) if $self->log->is_trace;
    $self->attr($attrs);
}

sub generate_pkcs7_response ($self, $response) {
    my %params = (
        alias           => $self->attr->{alias},
        transaction_id  => $self->transaction_id,
        request_nonce   => $self->attr->{sender_nonce},
        digest_alg      => $self->attr->{digest_alg},
        enc_alg         => $self->attr->{enc_alg},
        key_alg         => $self->attr->{key_alg},
    );

    if ($response->is_client_error) {

        # if an invalid recipient token was given, the alias is unset
        # the API will take the  default token to generate the reponse
        # but we must remove the undef value from the parameters list
        delete $params{alias} unless ($params{alias});

        my $failInfo;
        if ($response->error == 40001) {
            $failInfo = 'badMessageCheck';
        } elsif ($response->error == 40005) {
            $failInfo = 'badCertId';
        } else {
            $failInfo = 'badRequest';
        }

        $self->log->warn(sprintf('Client error / malformed request: %s (internal code: %s)', $failInfo, $response->error));
        return $self->backend->run_command('scep_generate_failure_response', {
            %params,
            failinfo => $failInfo,
        });
    # server errors must be handled before generate_pkcs7_response() is called
    } elsif ($response->is_server_error) {
        die "Unhandled server error";

    } elsif ($response->is_pending) {
        $self->log->info('Send pending response for ' . $self->transaction_id );
        return $self->backend->run_command('scep_generate_pending_response', \%params);

    } else {
        $params{chain} = $self->config->{output}->{chain} || 'chain';
        return $self->backend->run_command('scep_generate_cert_response', {
            %params,
            identifier => $response->result,
            signer => $self->signer,
        });
    }
}

__PACKAGE__->meta->make_immutable;

__END__;
