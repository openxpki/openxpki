package OpenXPKI::Client::Service::RPC;
use OpenXPKI -class;

with 'OpenXPKI::Client::Service::Role::Base';

sub service_name { 'rpc' } # required by OpenXPKI::Client::Service::Role::Base

# Core modules
use Exporter qw( import );

# Project modules
use OpenXPKI::Client::Service::Response;
use OpenXPKI::Serialization::Simple;

# Symbols to export by default
# (we avoid Moose::Exporter's import magic because that switches on all warnings again)
our @EXPORT = qw( cgi_safe_sub ); # provided by OpenXPKI::Client::Service::Role::Base

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

has use_status_codes => (
    is => 'rw',
    isa => 'Bool',
    lazy => 1,
    init_arg => undef,
    default => sub ($self) { $self->config->{output}->{use_http_status_codes} ? 1 : 0 },
);

# required by OpenXPKI::Client::Service::Role::Base
sub prepare { die "Not implemented yet" }

# required by OpenXPKI::Client::Service::Role::Base
sub send_response ($self, $c, $response) {
    die "Not implemented yet";

    # my $status = '200 OK';
    # my %retry_head;

    # if ($self->use_status_codes) {
    #     if ($response->has_error) {
    #         $status = $response->http_status_line;
    #     } elsif ($response->is_pending) {
    #         $status = '202 Request Pending - Retry Later';
    #         %retry_head = ('-retry-after' => $response->retry_after );
    #     }
    # }

    # if ($ENV{'HTTP_ACCEPT'} && $ENV{'HTTP_ACCEPT'} eq 'text/plain') {
    #     print $cgi->header( -type => 'text/plain', charset => 'utf8', -status => $status, %retry_head );
    #     if ($response->has_error) {
    #         print 'error.code=' . $response->error."\n";
    #         print 'error.message=' . $response->error_message."\n";
    #         printf "data.%s=%s\n", $_, $response->error_details->{$_} for keys $response->error_details->%*;

    #     } elsif ($response->has_result) {
    #         print 'id=' . $response->result->{id}."\n";
    #         print 'state=' . $response->result->{state}."\n";
    #         print 'retry_after=' . $response->retry_after ."\n" if $response->is_pending;

    #         my $data = $response->has_result ? ($response->result->{data} // {}) : {};
    #         printf "data.%s=%s\n", $_, $data->{$_} for keys $data->%*;
    #     }

    # } else {
    #     print $cgi->header( -type => 'application/json', charset => 'utf8', -status => $status );
    #     $json->max_depth(20);
    #     $json->canonical( $canonical_keys ? 1 : 0 );

    #     # run i18n tokenzier on output if a language is set
    #     print $json->encode( $config->language ? i18n_walk($response->result) : $response->result );
    # }
};

# required by OpenXPKI::Client::Service::Role::Base
sub op_handlers { die "Not implemented yet" }

# required by OpenXPKI::Client::Service::Role::Base
sub prepare_enrollment_result {}

# required by OpenXPKI::Client::Service::Role::Base
sub fcgi_set_custom_wf_params ($self) {
    # Only parameters which are whitelisted in the config are mapped!
    # This is crucial to prevent injection of server-only parameters
    # like the autoapprove flag...
    if ($self->config->{$self->operation}->{param}) {
        my @keys;
        @keys = split /\s*,\s*/, $self->config->{$self->operation}->{param};
        foreach my $key (@keys) {
            my $val = $self->request_param($key);
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

# Takes a key and returns either JSON value (if available) or the request parameter.
around request_param => sub ($orig, $self, $key) {
    if ($self->has_json_data) {
        return $self->json_data->{$key};
    } else {
        return $self->$orig($key);
    }
};

around new_response => sub ($orig, $self, %args) {
    my $response = $self->$orig(%args);

    # add workflow details to response
    if ($response->has_workflow) {
        my $wf = $response->workflow;

        my $details = {
            id => $wf->{id},
            proc_state => $wf->{proc_state},
            pid => $$,
        };

        # if the workflow is running, we do not expose any data of the workflows
        if ($wf->{proc_state} eq 'running') {
            $details->{'state'} = '--';
            $self->log->info(sprintf(
                'RPC request was processed properly. Workflow #%s: currently running',
                $wf->{id}
            ));

        } else {
            $details->{'state'} = $wf->{'state'};
            $self->log->info(sprintf(
                'RPC request was processed properly. Workflow #%s: state "%s" (%s)',
                $wf->{id}, $wf->{state}, $wf->{proc_state}
            ));
            # Add context parameters to the response if requested
            if (my $output = $self->config->{$self->operation}->{output}) {
                my @keys = split /\s*,\s*/, $output;
                $self->log->debug(sprintf 'Configured output keys for operation "%s": %s', $self->operation, join(', ', @keys));

                $details->{data} = {};
                for my $key (@keys) {
                    my $val = $wf->{context}->{$key};
                    next unless defined $val;
                    next unless ($val ne '' or ref $val);
                    if (OpenXPKI::Serialization::Simple::is_serialized($val)) {
                        $val = OpenXPKI::Serialization::Simple->new->deserialize($val);
                    }
                    $details->{data}->{$key} = $val;
                }
            }
        }

        $response->result($details);
    }

    return $response;
};

sub handle_rpc_request ($self) {
    my $conf = $self->config->{$self->operation}
        or $self->failure( 40480, sprintf 'RPC method "%s" not found', $self->operation );

    # "workflow" is required even though with "execute_action" we don't need it.
    # But the check here serves as a config validator so that a correct OpenAPI
    # Spec will be generated upon request.
    $self->failure( 40480, sprintf 'Configuration of RPC method "%s" must contain "workflow" entry', $self->operation ) unless $conf->{workflow};

    $self->log->trace(
        sprintf 'Incoming RPC request "%s" on endpoint "%s" with parameters: %s',
        $self->operation, $self->endpoint, Dumper $self->wf_params,
    ) if $self->log->is_trace;

    my $wf;

    #
    # Try pickup
    #
    my $pickup_key = $conf->{pickup};
    if ($pickup_key) {
        try {
            # pickup via workflow
            if (my $wf_type = $conf->{pickup_workflow}) {
                $wf = $self->pickup_via_workflow($wf_type, $pickup_key);

            # pickup via datapool
            } elsif (my $ns = $conf->{pickup_namespace}) {
                $wf = $self->pickup_via_datapool($ns, $self->request_param($pickup_key));

            # pickup via workflow attribute search
            } else {
                my $key = $conf->{pickup_attribute} || $pickup_key;
                my $value = $self->request_param($pickup_key);
                $wf = $self->pickup_via_attribute($conf->{workflow}, $key, $value);
            }
        }
        catch ($error) {
            if (blessed $error and $error->isa('OpenXPKI::Exception::WorkflowPickupFailed')) {
                $self->log->debug('Workflow pickup failed');
            }
            else {
                die $error;
            }
        }
    }

    # Endpoint has a "resume and execute" definition so run action if possible
    #
    # If "execute_action" is defined it enforces "pickup_workflow" and we never
    # start a new workflow, even if no "pickup" parameters were given.
    if (my $action = $conf->{execute_action}) {
        if (!$wf) {
            $self->failure( 40481 );

        } elsif ($wf->{proc_state} ne 'manual') {
            # TODO switch to Response, details are auto added
            $self->failure( 40482, { id => $wf->{id}, 'state' => $wf->{'state'}, proc_state => $wf->{proc_state} } );

        } else {
            my $actions_avail = $self->backend->run_command('get_workflow_activities', { id => $wf->{id} });
            if (!(grep { $_ eq $action } @{$actions_avail})) {
                $self->failure( 40483, { id => $wf->{id}, 'state' => $wf->{'state'}, proc_state => $wf->{proc_state} } );
            } else {
                $self->log->debug("Resume #".$wf->{id}." and execute '$action' with params: " . join(", ", keys $self->wf_params->%*));
                $wf = $self->backend->handle_workflow({
                    id => $wf->{id},
                    activity => $action,
                    params => $self->wf_params,
                });
            }
        }
    }

    #
    # Start new workflow if no pickup failed or was not configured
    #
    if (not $wf) {
        $self->log->debug(sprintf("Initialize workflow '%s' with parameters: %s",
            $conf->{workflow}, join(", ", keys $self->wf_params->%*)));

        $wf = $self->backend->handle_workflow({
            type => $conf->{workflow},
            params => $self->wf_params,
        });
    }

    $self->check_workflow_error($wf);

    # Error if pickup is not possible / configured
    # $self->throw_error(
    #     error => 40006,
    #     workflow => $wf,
    # ) if (not $pickup_key and $wf->{proc_state} ne 'finished');

    # Workflow paused - send "request pending" / ask client to retry
    if ($pickup_key and $wf->{proc_state} ne 'finished') {
        return $self->new_pending_response($wf);

    } else {
        return $self->new_response(workflow => $wf);
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
# Also logs the error via $self->log->error().
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

    my $details = { pid => $$ };
    my $msg_log = '';
    my $msg_public = '';

    # check remaining arguments
    for my $arg (@args) {
        # Scalar = additional error message
        if (not ref $arg and length($arg)) {
            $msg_public = $arg;
            $msg_log = $arg;
        }
        # ArrayRef = two different additional error messages [external, internal]
        elsif (ref $arg eq 'ARRAY') {
            $msg_public = $arg->[0];
            $msg_log = $arg->[1];
        }
        # HashRef = additional data
        elsif (ref $arg eq 'HASH') {
            $details = { %$details, %$arg };
        }
    }

    $self->log->error(sprintf '%s: %s', $code, $msg_log);

    $self->throw_error(
        error => $code,
        error_message => $msg_public,
        error_details => $details,
    );
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
