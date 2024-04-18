package OpenXPKI::Client::Service::RPC;
use OpenXPKI -class;

with qw(
    OpenXPKI::Client::Service::Role::Base
    OpenXPKI::Client::Service::Role::PickupWorkflow
);

sub service_name { 'rpc' } # required by OpenXPKI::Client::Service::Role::Base

# Project modules
use OpenXPKI::Client::Service::Response;


has json_data => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    predicate => 'has_json_data',
);

has pkcs7 => (
    is => 'rw',
    isa => 'Str',
    init_arg => undef,
    lazy => 1,
    default => sub { {} },
);

has pkcs7_content => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    predicate => 'has_pkcs7_content',
);

has jwt_header => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    predicate => 'has_jwt_header',
);

# required by OpenXPKI::Client::Service::Role::Base
sub prepare { die "Not implemented yet" }

# required by OpenXPKI::Client::Service::Role::Base
sub send_response { die "Not implemented yet" }

# required by OpenXPKI::Client::Service::Role::Base
sub op_handlers { die "Not implemented yet" }

# required by OpenXPKI::Client::Service::Role::Base
sub fcgi_set_custom_wf_params ($self) {
    # Only parameters which are whitelisted in the config are mapped!
    # This is crucial to prevent injection of server-only parameters
    # like the autoapprove flag...
    if ($self->config->{$self->operation}->{param}) {
        my @keys;
        @keys = split /\s*,\s*/, $self->config->{$self->operation}->{param};
        foreach my $key (@keys) {
            my $val = $self->get_param($key);
            next unless (defined $val);

            if (!ref $val) {
                $val =~ s/\A\s+//;
                $val =~ s/\s+\z//;
            }
            $self->add_wf_param($key => $val);
        }
    }

    # Gather data from TLS session
    if ($self->request->is_secure) {
        my $auth_dn = $self->apache_env->{SSL_CLIENT_S_DN};
        my $auth_pem = $self->apache_env->{SSL_CLIENT_CERT};

        # TODO tls_client_dn / tls_client_cert always have the same value as signer_dn / signer_cert
        if (defined $auth_dn) {
            $self->add_wf_param(tls_client_dn => $auth_dn) if $self->config_env_keys->{tls_client_dn};

            if ($auth_pem) {
                $self->add_wf_param(tls_client_cert => $auth_pem) if $self->config_env_keys->{tls_client_cert};
                if (
                    ($self->config_env_keys->{signer_chain} or $self->config_env_keys->{tls_client_chain})
                    and $self->apache_env->{SSL_CLIENT_CERT_CHAIN_0}
                ) {
                    my @chain;
                    for (my $cc=0; $cc<=3; $cc++)   {
                        my $chaincert = $self->apache_env->{'SSL_CLIENT_CERT_CHAIN_' . $cc};
                        last unless $chaincert;
                        push @chain, $chaincert;
                    }
                    $self->add_wf_param(signer_chain => \@chain) if $self->config_env_keys->{signer_chain};
                    $self->add_wf_param(tls_client_chain => \@chain) if $self->config_env_keys->{tls_client_chain};
                }
            }
        }
    }

    if ($self->has_pkcs7_content) {
        $self->add_wf_param(_pkcs7 => $self->pkcs7) if $self->config_env_keys->{pkcs7};
        $self->add_wf_param(signer_cert => $self->pkcs7_content->{signer}) if $self->config_env_keys->{signer_cert};
    }

    if ($self->has_jwt_header) {
        $self->add_wf_param(signer_cert => $self->jwt_header->{signer_cert}) if $self->config_env_keys->{signer_cert};
    }
}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare_enrollment_result { die "Not implemented yet" }

# Takes a key and returns either JSON value (if available) or the request parameter.
sub get_param ($self, $k) {
    if ($self->has_json_data) {
        return $self->json_data->{$k}; # UTF-8 decoding already done by JSON modules

    } else {
        my $raw = $self->query_params->param($k);  # assume this is an UTF-8 encoded octet stream
        return unless defined $raw; # ..to be able to test for undef below
        # decode UTF-8
        my $value;
        try {
            $value = Encode::decode("UTF-8", $raw, Encode::LEAVE_SRC | Encode::FB_CROAK)
                or $self->failure(40086, [undef, "Could not decode field '$k'"]);
        }
        catch ($error) {
            $self->failure(40086, [undef, "Could not decode field '$k': $error"]);
        }

        return $value;
    }
}

# Takes the given error code and returns a HashRef like
#   {
#     error => {
#       code => 50000,
#       message => "...",
#       data => { pid => $$, ... },
#     }
#   }
# Also logs the error via $log->error().
#
# Parameters:
#   $code - error code (Int)
#   $message - optional: additional error message (Str)
#   $messages - optional: two different messages for logging (internal) and client result (public) (ArrayRef)
#   $data - optional: additional information for 'data' part (HashRef)
#
# Example:
#   failure( 50007, "Error details" );
sub failure {
    my $self = shift;
    my $code = shift;
    my @args = @_;

    my $message = $OpenXPKI::Client::Service::Response::named_messages{$code} // 'Unknown error';
    my $data = { pid => $$ };
    my $details_log = '';
    my $details_public = '';

    # check remaining arguments
    for my $arg (@args) {
        # Scalar = additional error message
        if (not ref $arg and length($arg)) {
            $details_public = ': '.$arg;
            $details_log = ': '.$arg;
        }
        # ArrayRef = two different additional error messages [external, internal]
        elsif (ref $arg eq 'ARRAY') {
            $details_public = ': '.$arg->[0];
            $details_log = ': '.$arg->[1];
        }
        # HashRef = additional data
        elsif (ref $arg eq 'HASH') {
            $data = { %$data, %$arg };
        }
    }

    $self->log->error(sprintf '%s - %s%s', $code, $message, $details_log);

    my $resp = OpenXPKI::Client::Service::Response->new_error($code => $message.$details_public);
    $resp->result({ data => $data });

    die $resp;
}

sub openapi_spec {

    my $self = shift;
    my $openapi_server_url = shift;
    my $conf = $self->config;

    my $paths = {};

    # global OpenAPI component definitions for reusable things
    my $components = {
        schemas => {},
        parameters => {},
        securitySchemes => {},
        requestBodies => {},
        responses => {},
        headers => {},
        examples => {},
        links => {},
        callbacks => {},
    };

    my $openapi_spec = {
        openapi => "3.0.0",
        info => {
            title => "OpenXPKI RPC API",
            $conf->{openapi} ? ($conf->{openapi}->%*) : (),
        },
        servers => [ { url => $openapi_server_url, description => "OpenXPKI server" } ],
        paths => $paths,
        components => $components,
    };

    my $add_path = sub {
        my ($url, $spec) = @_;
        $paths->{$url} = $spec;
    };

    my $add_component = sub {
        my ($section, $spec) = @_;
        die "Unknown OpenAPI component sub-section '$section'" unless exists $components->{$section};
        # append new specs or overwrite existing ones (e.g. same pickup workflow
        # payload might be returned by get_rpc_openapi_spec multiple times)
        $components->{$section} = { $components->{$section}->%*, $spec->%* };
    };

    my %err_msgs = %OpenXPKI::Client::Service::Response::named_messages;

    $add_component->(schemas => {
        Error => {
            type => 'object',
            properties => {
                'error' => {
                    type => 'object',
                    description => 'Only set if an error occured while executing the command',
                    required => [qw( code message data )],
                    properties => {
                        'code' => {
                            type => 'integer',
                            description => "Code indicating the type of error:\n"
                                . join("\n", map { " * $_ - ".$err_msgs{$_} } sort keys %err_msgs),
                            enum => [ map { $_+0 } sort keys %err_msgs ],
                        },
                        'message' => {
                            type => 'string',
                        },
                        'data' => {
                            type => 'object',
                            properties => {
                                'pid' => { type => 'integer', },
                            },
                        },
                    },
                },
            },
        },
    });

    try {
        my $client = $self->backend()
          or die "Could not create OpenXPKI client\n";

        if (!$openapi_spec->{info}->{version}) {
            my $server_version = $client->run_command('version');
            $openapi_spec->{info}->{version} = $server_version->{config}->{api} || 'unknown';
        }

        for my $method (sort keys %$conf) {
            next if $method =~ /^[a-z]/; # small letters means: no RPC method but a config group
            my $wf_type = $conf->{$method}->{workflow}
              or die "Missing parameter 'workflow' in RPC method '$method'\n";
            my $in = $conf->{$method}->{param} || '';
            my $out = $conf->{$method}->{output} || '';
            my $action = $conf->{$method}->{execute_action};

            my $pickup_workflow = $conf->{$method}->{pickup_workflow};
            my $pickup_input = $conf->{$method}->{pickup};

            my $method_spec = $client->run_command('get_rpc_openapi_spec', {
                rpc_method => $method,
                workflow => $wf_type,
                ($action ? (action => $action) : ()),
                input => [ split /\s*,\s*/, $in ],
                output => [ split /\s*,\s*/, $out ],
                $pickup_workflow ? (pickup_workflow => $pickup_workflow) : (),
                $pickup_input ? (pickup_input => [ split /\s*,\s*/, $pickup_input ]) : (),
            });

            my $responses = {
                '200' => {
                    description => "JSON object with details either about the command result or the error",
                    content => {
                        'application/json' => {
                            schema => {
                                oneOf => [
                                    {
                                        type => 'object',
                                        properties => {
                                            'result' => {
                                                type => 'object',
                                                description => 'Only set if command was successfully executed',
                                                required => [qw( data state pid id )],
                                                properties => {
                                                    'data' => $method_spec->{output_schema},
                                                    'state' => { type => 'string' },
                                                    'proc_state' => { type => 'string' },
                                                    'pid' => { type => 'integer', },
                                                    'id' => { type => 'integer', },
                                                },
                                            },
                                        },
                                    },
                                    {
                                        '$ref' => '#/components/schemas/Error',
                                    },
                                ],
                            },
                        },
                    },
                },
            };


            if ($method_spec->{input_schema}) {
                $add_path->("/$method" => {
                    post => {
                        description => $method_spec->{description},
                        requestBody => {
                            required => JSON::true,
                            content => {
                                'application/json' => {
                                    schema => $method_spec->{input_schema},
                                },
                            },
                        },
                        responses => $responses,
                    },
                });
            } else {
                $add_path->("/$method" => {
                    get => {
                        description => $method_spec->{description},
                        responses => $responses,
                    },
                });
            }

            $add_component->($_, $method_spec->{components}->{$_}) for keys $method_spec->{components}->%*;
        }

        $client->disconnect();
    }
    catch ($err) {
        $self->log->error("Unable to query OpenAPI specification from OpenXPKI server: $err");
        return;
    }

    return $openapi_spec;

}

__PACKAGE__->meta->make_immutable;

__END__;
