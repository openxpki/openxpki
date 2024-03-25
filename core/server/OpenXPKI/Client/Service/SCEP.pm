package OpenXPKI::Client::Service::SCEP;
use OpenXPKI -class;

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

sub pkcs7message ($self, $pkcs7) {
    die "PKCS7 message is not set or empty" unless $pkcs7;

    my $attrs = {};
    try {
        $attrs = $self->backend->run_command('scep_unwrap_message', {
            message => $pkcs7
        });
    }
    catch ($err) {
        $self->log->error("Unable to unwrap PKCS7 message: $err");
        die "Unable to unwrap PKCS7 message";
    }

    $self->log->trace("Unwrapped PKCS7 message: " . Dumper $attrs) if $self->log->is_trace;
    $self->attr($attrs);
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
sub op_handlers {
    die "Not implemented yet";
}

# required by OpenXPKI::Client::Service::Base
sub prepare_enrollment_result ($self, $workflow) {
    return OpenXPKI::Client::Service::Response->new(
        workflow => $workflow,
        result => $workflow->{context}->{cert_identifier},
    );
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
