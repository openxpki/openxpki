package OpenXPKI::Client::Service::SCEP;
use OpenXPKI qw( -class -nonmoose );

extends 'Mojolicious::Controller';
with 'OpenXPKI::Client::Service::Base';

sub service_name { 'scep' } # required by OpenXPKI::Client::Service::Base

use MIME::Base64;
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
);

has _binary_type => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef,
);


sub index ($self) {
    # strip .exe
    my $op = $self->operation; $op =~ s/\.exe$//i; $self->operation($op);

    # my $server = $ep_config->{global}->{servername} || $endpoint;
    # if (not $server) {
    #     $self->log->error('Server not set: empty endpoint and no default server set');
    #     $self->res->code(404);
    #     $self->res->message('Not Found (no such server)');
    #     return $self->render(text => "Server not set");
    # }

    # Log::Log4perl::MDC->put('server', $server);

    my $response = $self->handle_request;

    # HTTP header
    if ($self->config->{output}->{headers}) {
        $self->res->headers->add($_ => $response->extra_headers->{$_}) for keys $response->extra_headers->%*;
    }

    # Response

    --> Order of processing of 'application/x-pki-message' header is wrong.
        We read it before we set it. Still necessary as a flag?

    if ('application/x-pki-message' eq $self->res->headers->content_type) {
        my $out = $self->generate_pkcs7_response( $response );
        $self->disconnect_backend;

        $self->log->trace('PKCS7 response: ' . $out) if $self->log->is_trace;
        $out = decode_base64($out);
        return $self->render(data => $out);

    } elsif ($response->has_error) {
        return $self->render(text => $response->error_message);

    } else {
        $self->log->trace('Response: ' . $response->result) if $self->log->is_trace;

        if (my $type = $self->_binary_type) {
            $self->res->headers->content_type($type);
            return $self->render(data => decode_base64($response->result));
        } else {
            return $self->render(text => $response->result);
        }
    }

}

# required by OpenXPKI::Client::Service::Base
sub op_handlers {
    return [
        'PKIOperation' => sub ($self) {
            my $message;
            # get the message from the GET string and decode base64
            if ($self->req->method eq 'GET') {
                $message = $self->req->url->query->param('message');
                $self->log->debug("Got PKIOperation via GET");

            } else {
                $message = encode_base64($self->req->body, '');
                if (not $message) {
                    $self->log->error("POSTDATA is empty - check documentation on required setup for Content-Type headers!");
                    $self->log->debug("Content-Type is " . ($self->req->headers->content_type || 'undefined'));
                    return OpenXPKI::Client::Service::Response->new( 40003 );
                }
                $self->log->debug("Got PKIOperation via POST");
            }
            $self->log->trace("Decoded SCEP message: " . $message) if $self->log->is_trace;

            # this internally triggers a call to the backend to unwrap the
            # scep message and returns the payload and some attributes
            # will die in case of an error, so an eval is needed here!
            try {
                $self->set_pkcs7_message( $message );
            }
            # something is wrong, TODO we might try to branch request vs. server errors
            catch ($err) {
                return OpenXPKI::Client::Service::Response->new( 50010 );
            }

            $self->res->headers->content_type('application/x-pki-message'); # only set after successfully decoding the PKCS#7 request

            if (not $self->attr->{alias}) {
                $self->log->info('Unable to find RA certficate');
                return OpenXPKI::Client::Service::Response->new ( 40002 );

            } elsif (not $self->signer) {
                $self->log->info('Unable to extract signer certficate');
                return OpenXPKI::Client::Service::Response->new ( 40001 );

            # Enrollment request
            } elsif ($self->message_type =~ m{(PKCSReq|RenewalReq|GetCertInitial)}) {
                # TODO - improve handling of GetCertInitial and RenewalReq
                $self->log->debug("Handle enrollment");
                return $self->handle_enrollment_request;

            # Request for CRL or GetCert with IssuerSerial in Payload
            } else {
                $self->operation($self->message_type);
                return $self->handle_property_request;
            }

        },
        'GetCACaps' => sub ($self) {
            my $response = $self->handle_property_request;
            return $response;
        },
        'GetCACert' => sub ($self) {
            $self->binary_type('application/x-x509-ca-ra-cert');
            return $self->handle_property_request;
        },
        'GetNextCACert' => sub ($self) {
            $self->binary_type('application/x-x509-next-ca-cert');
            return $self->handle_property_request;
        },
    ];
}

# required by OpenXPKI::Client::Service::Base
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

# required by OpenXPKI::Client::Service::Base
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
        $self->log->error("Unable to unwrap PKCS7 message: $err");
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

    if ($response->is_pending) {
        $self->log->info('Send pending response for ' . $self->transaction_id );
        return $self->backend->run_command('scep_generate_pending_response', \%params);
    }

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

        $self->log->warn('Client error / malformed request ' . $failInfo);
        return $self->backend->run_command('scep_generate_failure_response', {
            %params,
            failinfo => $failInfo,
        });
    }

    if (not $response->is_server_error) {
        $params{chain} = $self->config->{output}->{chain} || 'chain';
        return $self->backend->run_command('scep_generate_cert_response', {
            %params,
            identifier => $response->result,
            signer => $self->signer,
        });
    }

    return;
}

__PACKAGE__->meta->make_immutable;

__END__;
