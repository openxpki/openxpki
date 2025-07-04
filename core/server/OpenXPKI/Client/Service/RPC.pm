package OpenXPKI::Client::Service::RPC;
use OpenXPKI -class;

with qw(
    OpenXPKI::Client::Service::Role::Info
    OpenXPKI::Client::Service::Role::Base
);

# Core modules
use Exporter qw( import );
use JSON::PP;
use List::Util qw(any);

# CPAN modules
use Crypt::JWT qw( decode_jwt );

# Project modules
use OpenXPKI::Client::Service::Response;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::i18n qw( i18n_walk get_language );

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
    default => sub ($self) { $self->config->get('output.use_http_status_codes') ? 1 : 0 },
);

has openapi_mode => (
    is => 'rw',
    isa => 'Bool',
    lazy => 1,
    init_arg => undef,
    default => 0,
);

# required by OpenXPKI::Client::Service::Role::Info
sub declare_routes ($r) {
    # RPC urls look like
    #   /rpc/enroll?method=IssueCertificate
    #   /rpc/enroll/IssueCertificate
    $r->any('/rpc/<endpoint>/<method>')->to(
        service_class => __PACKAGE__,
        method => '',
    );
}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare ($self, $c) {
    #
    # Parse request
    #
    $self->try_set_operation($self->request_param('method'));
    $self->parse_rpc_request_body;
    $self->try_set_operation($c->stash('method'));
    die $self->new_response( 40080 ) unless $self->has_operation;

    #
    # Add custom workflow parameters
    #
    # Gather data from TLS session
    if ($self->request->is_secure) {
        my $auth_dn = $self->request->env->{SSL_CLIENT_S_DN};
        my $auth_pem = $self->request->env->{SSL_CLIENT_CERT};

        # TODO tls_client_dn / tls_client_cert always have the same value as signer_dn / signer_cert
        if (defined $auth_dn) {
            $self->add_wf_param(tls_client_dn => $auth_dn) if $self->config_env_keys->{tls_client_dn};

            if ($auth_pem) {
                $self->add_wf_param(tls_client_cert => $auth_pem) if $self->config_env_keys->{tls_client_cert};
                if (
                    ($self->config_env_keys->{signer_chain} or $self->config_env_keys->{tls_client_chain})
                    and $self->request->env->{SSL_CLIENT_CERT_CHAIN_0}
                ) {
                    my @chain;
                    for (my $cc=0; $cc<=3; $cc++)   {
                        my $chaincert = $self->request->env->{'SSL_CLIENT_CERT_CHAIN_' . $cc};
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

    # Only parameters which are whitelisted in the config are mapped!
    # This is crucial to prevent injection of server-only parameters
    # like the autoapprove flag...
    if (my @keys = $self->config->get_list([$self->operation,'input'])) {
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
}

# required by OpenXPKI::Client::Service::Role::Base
sub send_response ($self, $c, $response) {
    if ($self->use_status_codes) {
        if ($response->is_pending) {
            $c->res->headers->add('Retry-After' => $response->retry_after);
        }
    } else {
        $c->res->code('200');
        $c->res->message('OK');
    }

    # plain text
    if (($c->req->headers->accept//'') eq 'text/plain') {
        my $output;

        if ($response->has_error) {
            $output.= sprintf "error.code=%s\n", $response->error;
            $output.= sprintf "error.message=%s\n", $response->error_message;
            $output.= sprintf "data.%s=%s\n", $_, $response->error_details->{$_} for keys $response->error_details->%*;

        } elsif ($response->has_result) {
            $output.= sprintf "id=%s\n", $response->result->{id};
            $output.= sprintf "state=%s\n", $response->result->{state};
            $output.= sprintf "retry_after=%s\n", $response->retry_after if $response->is_pending;

            my $data = $response->has_result ? ($response->result->{data} // {}) : {};
            $output.= sprintf "data.%s=%s\n", $_, $data->{$_} for keys $data->%*;
        }

        return $c->render(text => $output);


    # endpoint should send content directly
    } elsif ($self->config->exists([$self->operation,'download'])) {

        my $download = $self->config->get_hash([$self->operation,'download']);

        $self->log->debug('Direct download configured');
        # the payload of the workflow
        my $data = $response->result->{data} || {};

        $self->log->trace(Dumper $data) if $self->log->is_trace;

        my $payload;
        my $mime = $download->{mime} || 'application/octet-stream';
        my $filename = $download->{filename};

        # download config must specify a field to read the data from
        # or a template string to be applied on the data hash
        if (my $template = $download->{template}) {
            $self->log->debug('Rendering template using context '. $template);
            $payload  = OpenXPKI::Template->new()->render($template, $data);
        } else {
            my $field = $download->{field} || 'output';
            $self->log->debug('Read payload from '. $field);
            $payload = $data->{$field} // '';

            # support download field format from UI (hash with data and header)
            if (ref $payload eq 'HASH') {
                $filename = $payload->{filename} if ($payload->{filename});
                $mime = $payload->{mime} if ($payload->{mime});
                $payload = $payload->{data};
            }

            # support for array of certificates/crls
            if (ref $payload eq 'ARRAY') {
                $payload = join("\n", $payload->@*);
            }
        }

        if (!$payload) {
            $c->res->code('404');
            $c->res->message('Not found');
            return $c->render();
        }

        $self->log->trace(Dumper $payload);

        $c->res->headers->content_type($download->{mime} || 'application/octet-stream');
        $c->res->headers->content_disposition("attachment;filename=".$download->{filename})
            if ($download->{filename});

        return $c->render(text => $payload);

    # JSON
    } else {
        my $data;

        if ($response->has_error) {
            $data = {
                error => {
                    code => $response->error,
                    message => $response->error_message,
                    $response->has_error_details ?
                        (data => (get_language() ? i18n_walk($response->error_details) : $response->error_details)) : (),
                }
            };

        } else {
            # run i18n tokenzier on output if a language is set
            $data = get_language() ? i18n_walk($response->result) : $response->result;
            # wrap in "result" hash item
            if (not $self->openapi_mode) {
                $data = {
                    result => {
                        $data->%*,
                        $response->is_pending ? (retry_after => $response->retry_after) : (),
                    }
                };
            }
        }

        # JSON encoding
        $self->json->max_depth(20);
        $self->json->canonical($self->openapi_mode);
        my $json_str = $self->json->encode($data);

        return $c->render(data => $json_str, format => 'json'); # formats are defined in Mojolicious::Types
    }
}

# required by OpenXPKI::Client::Service::Role::Base
sub op_handlers {
    return [
        'openapi-spec' => sub ($self) {
            $self->openapi_mode(1);
            my $url = $self->normalized_request_url; # includes path with leading slash
            my $baseurl = sprintf "%s://%s%s", $url->protocol, $url->host_port, $url->path;
            my $spec = $self->openapi_spec($baseurl) or die $self->new_response( 50082 );
            return $self->new_response(result => $spec);
        },
        qr/^.*/ => \&handle_rpc_request,
    ];
}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare_enrollment_result {}

# required by OpenXPKI::Client::Service::Role::Base
sub cgi_set_custom_wf_params ($self) {
    # Only parameters which are whitelisted in the config are mapped!
    # This is crucial to prevent injection of server-only parameters
    # like the autoapprove flag...
    if (my @keys = $self->get_list_from_config([$self->operation,'param'])) {
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
        my $auth_dn = $self->request->env->{SSL_CLIENT_S_DN};
        my $auth_pem = $self->request->env->{SSL_CLIENT_CERT};

        # TODO tls_client_dn / tls_client_cert always have the same value as signer_dn / signer_cert
        if (defined $auth_dn) {
            $self->add_wf_param(tls_client_dn => $auth_dn) if $self->config_env_keys->{tls_client_dn};

            if ($auth_pem) {
                $self->add_wf_param(tls_client_cert => $auth_pem) if $self->config_env_keys->{tls_client_cert};
                if (
                    ($self->config_env_keys->{signer_chain} or $self->config_env_keys->{tls_client_chain})
                    and $self->request->env->{SSL_CLIENT_CERT_CHAIN_0}
                ) {
                    my @chain;
                    for (my $cc=0; $cc<=3; $cc++)   {
                        my $chaincert = $self->request->env->{'SSL_CLIENT_CERT_CHAIN_' . $cc};
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

around new_response => sub ($orig, $self, @args) {
    my $response = $self->$orig(@args);

    # add workflow details to response
    if ($response->has_workflow) {
        my $wf = $response->workflow;

        my $data;

        no warnings "numeric"; # int("V435435") would give a warning
        my $details = {
            id => int($wf->{id}),
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
            if (my @keys = $self->get_list_from_config([$self->operation,'output'])) {
                $self->log->debug(sprintf 'Configured output keys for operation "%s": %s', $self->operation, join(', ', @keys));
                for my $key (@keys) {
                    my $val = $wf->{context}->{$key};
                    next unless defined $val;
                    next unless ($val ne '' or ref $val);
                    if (OpenXPKI::Serialization::Simple::is_serialized($val)) {
                        $val = OpenXPKI::Serialization::Simple->new->deserialize($val);
                    }
                    $data->{$key} = $val;
                }
            }
        }

        if ($response->has_error) {
            $response->error_details({
                $response->has_error_details ? ($response->error_details->%*) : (),
                $details->%*,
                $data ? ($data->%*) : (),
            });

        } else {
            $response->result({
                $details->%*,
                $data ? (data => $data) : (),
            });
        }
    }

    return $response;
};

sub try_set_operation ($self, $op) {
    return if $self->has_operation;
    return unless $op;
    $self->operation($op);
}

sub parse_rpc_request_body ($self) {
    my $content_type = $self->request->headers->content_type;

    $self->log->trace('HTTP request method: ' . $self->request->method);

    #
    # Old school ulencoded GET parameters
    #
    if ($self->request->method eq 'GET') {
        $self->log->debug("RPC GET request");
        $self->log->trace("URL encoded payload: " . Dumper $self->request->params->to_hash) if $self->log->is_trace;
        return;
    }

    $self->log->debug("RPC POST data with Content-Type: $content_type");

    #
    # Standard forms are handled by Mojolicious
    #
    if (
        $content_type =~ m{\Aapplication/x-www-form-urlencoded} or
        $content_type =~ m{\Amultipart/form-data}
    ) {
        $self->log->trace("URL encoded payload: " . Dumper $self->request->params->to_hash) if $self->log->is_trace;
        return; # no parsing required: Mojolicious already decoded the request parameters
    }

    die $self->new_response( 40083 ) unless $self->config->get('input.allow_raw_post');

    return unless $self->request->body;

    my $json_str;
    #
    # application/jose
    #
    if ($content_type =~ m{\Aapplication/jose}) {

        # exist does not work here as the section is currently empty/undef
        die $self->new_response( 40087 )
            unless (any { $_ eq 'jose' } $self->config->get_keys());

        # The cert_identifier used to sign the token must be set as kid
        # First run - set ignore_signature to just get the header with the kid
        my ($cert_identifier, $cert);
        my ($jwt_header, undef) = decode_jwt(
            token => $self->request->body,
            ignore_signature => 1,
            decode_header => 1,
            decode_payload => 0,
        );

        if ($jwt_header->{alg} !~ m{\A(R|E)S256\z}) {
            die $self->new_response(
                error => 40090,
                error_details => { alg => $jwt_header->{alg} },
            );
        }

        $self->jwt_header($jwt_header);

        # we currently only support "known" certificates as signers
        # the recommended way is to use the x5t header field
        if ($jwt_header->{x5t}) {
            $cert_identifier = $jwt_header->{x5t};
            $self->log->debug("JWT header has x5t set to $cert_identifier");

        # as a fallback we support passing the identifier in the kid field
        # to allow adding other key patterns later we use a namespace
        } elsif (substr(($jwt_header->{kid}//''), 0, 6) eq 'certid') {
            $cert_identifier = substr($jwt_header->{kid}, 7);
            $self->log->debug("JWT header has kid set to $cert_identifier");

        } else {
            die $self->new_response( 40088, "No key id was found in the JWT header" );
        }

        # to prevent nasty attacks we require that the method name is part of the protected header
        my $op = $jwt_header->{method} or die $self->new_response( 40089 );
        $self->operation($op);

        my $backend = $self->client_simple; # call outside the following try-catch block so OpenXPKI::Exception is not mangled
        try {
            # this will die if the certificate was not found
            # TOOD - this call fails if no backend connection can be made which gives a misleading
            # error code to the customer - this can also happen on a misconfigured auth stack :)
            # might also be useful to have a validated "certificate" used for the session login
            # so the likely best option would be some kind on "anonymous" client here
            # See #903 and #904 on github
            $cert = $backend->run_command('get_cert', { identifier => $cert_identifier, format => 'PEM' });

            # use our json parser object to decode to limit parsing depth
            $json_str = decode_jwt(token => $self->request->body, key => \$cert, decode_payload => 0);
            $self->log->trace("JWT encoded JSON payload: $json_str") if $self->log->is_trace;

            $jwt_header->{signer_cert} = $cert;
        }
        catch ($error) {

            # rethrow error reponse
            die $error if ($error->isa('OpenXPKI::Client::Service::Response'));

            die $self->new_response( 40088, $cert ? 'JWT signature could not be verified' : 'Given key id was not found' );
        }

        $self->jwt_header($jwt_header);
    #
    # application/pkcs7
    #
    } elsif ($content_type =~ m{\Aapplication/pkcs7}) {

        # exist does not work here as the section is currently empty/undef
        die $self->new_response( 40091 )
            unless (any { $_ eq 'pkcs7' } $self->config->get_keys());

        $self->pkcs7($self->request->body);

        my $backend = $self->client_simple; # call outside the following try-catch block so OpenXPKI::Exception is not mangled
        try {
            my $pkcs7_content = $backend->run_command('unwrap_pkcs7_signed_data', {
                pkcs7 => $self->pkcs7,
            });
            $self->pkcs7_content($pkcs7_content);
            $self->log->trace("PKCS7 content: " . Dumper $pkcs7_content) if $self->log->is_trace;
            $json_str = $pkcs7_content->{value} or die $self->new_response( 50080 );
        }
        catch ($error) {
            # rethrow error reponse
            die $error if ($error->isa('OpenXPKI::Client::Service::Response'));

            die $self->new_response( 50080, $error );
        }

        $self->log->trace("PKCS7 payload: " . $json_str) if $self->log->is_trace;

    #
    # application/json
    #
    } elsif ($content_type =~ m{\Aapplication/json}) {

        $json_str = $self->request->body;

        $self->log->trace("JSON payload: " . $json_str) if $self->log->is_trace;

    #
    # unknown content type
    #
    } else {

        die $self->new_response(
            error => 40084,
            error_details => { type => $content_type },
        );
    }

    die $self->new_response( 40081 ) unless $json_str;

    # TODO - evaluate security implications regarding blessed objects
    # and consider to filter out serialized objects for security reasons
    $self->json->max_depth( $self->config->get('input.parse_depth') || 5 );

    # decode JSON
    try {
        my $json_data = $self->json->decode($json_str);
        $self->json_data($json_data);
        # read operation from JSON data if not found in URL before
        $self->try_set_operation($json_data->{method});
    }
    catch ($error) {
        $self->log->error($error);
        die $self->new_response( 40081 );
    }
}

sub handle_rpc_request ($self) {
    my $conf = $self->config->get_hash($self->operation)
        or die $self->new_response( 40480 => sprintf 'RPC method "%s" not found', $self->operation );

    # "workflow" is required even though with "execute_action" we don't need it.
    # But the check here serves as a config validator so that a correct OpenAPI
    # Spec will be generated upon request.
    die $self->new_response( 40480 => sprintf 'Configuration of RPC method "%s" must contain "workflow" entry', $self->operation )
      unless $conf->{workflow};

    $self->log->trace("RPC workflow config: " . Dumper $conf)  if $self->log->is_trace;

    my $wf;

    #
    # Try pickup
    #
    if ($conf->{pickup}) {
        $wf = $self->pickup_request($conf->{pickup}, $conf->{workflow});
    }

    # Endpoint has a "resume and execute" definition so run action if possible
    #
    # If "execute_action" is defined it enforces "pickup_workflow" and we never
    # start a new workflow, even if no "pickup" parameters were given.
    if (my $action = $conf->{execute_action}) {
        if (!$wf) {
            die $self->new_response( 40481 );

        } elsif ($wf->{proc_state} ne 'manual') {
            die $self->new_response( error => 40482, workflow => $wf );

        } else {
            my $actions_avail = $self->client_simple->run_command('get_workflow_activities', { id => $wf->{id} });
            if (!(grep { $_ eq $action } @{$actions_avail})) {
                die $self->new_response( error => 40483, workflow => $wf );
            } else {
                $self->log->debug("Resume #".$wf->{id}." and execute '$action' with params: " . join(", ", keys $self->wf_params->%*));
                $wf = $self->run_workflow(
                    id => $wf->{id},
                    activity => $action,
                    params => $self->wf_params,
                );
            }
        }
    }

    #
    # Start new workflow if no pickup failed or was not configured
    #
    if (not $wf) {
        $self->log->debug(sprintf("Initialize workflow '%s' with parameters: %s",
            $conf->{workflow}, join(", ", keys $self->wf_params->%*)));

        $wf = $self->run_workflow(
            type => $conf->{workflow},
            params => $self->wf_params,
        );
    }

    # Error if pickup is not possible / configured
    # die $self->new_response(
    #     error => 40006,
    #     workflow => $wf,
    # ) if (not $pickup_key and $wf->{proc_state} ne 'finished');

    # Workflow paused - send "request pending" / ask client to retry
    if ($conf->{pickup} and $wf->{proc_state} ne 'finished') {
        return $self->new_pending_response($wf);

    } else {
        return $self->new_response(workflow => $wf);
    }

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
            %{$conf->get_hash('openapi')//{}}
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
        if (!$openapi_spec->{info}->{version}) {
            my $server_version = $self->client_simple->run_command('version');
            $openapi_spec->{info}->{version} = $server_version->{config}->{api} || 'unknown';
        }

        for my $method (sort $conf->get_keys()) {
            next if $method =~ /^[a-z]/; # small letters means: no RPC method but a config group
            my $wf_type = $conf->get([$method, 'workflow'])
              or die "Missing parameter 'workflow' in RPC method '$method'\n";

            my @in = $conf->get_list([$method,'input']);
            if (!@in) {
                # legacy config uses atrribute "param"
                @in = $self->get_list_from_config([$method, 'param']);
            }

            my @out = $self->get_list_from_config([$method, 'output']);
            my $action = $conf->get([$method, 'execute_action']);

            # the structure for pickup has changed so we need some more glue code here
            my $pickup_workflow;
            my @pickup_input;

            if ($self->has_legacy_config) {
                $pickup_workflow = $conf->get([$method, 'pickup_workflow']);
                @pickup_input = $self->get_list_from_config([$method, 'pickup']);
            } else {
                $pickup_workflow = $conf->get([$method, 'pickup', 'workflow']);
                @pickup_input = $conf->get_list([$method, 'pickup', 'input']);
            }

            $self->log->debug("Fetch openapi-spec for $method / $wf_type");
            my $method_spec = $self->client_simple->run_command('get_rpc_openapi_spec', {
                rpc_method => $method,
                workflow => $wf_type,
                ($action ? (action => $action) : ()),
                input => \@in,
                output => \@out,
                $pickup_workflow ? (pickup_workflow => $pickup_workflow) : (),
                @pickup_input ? (pickup_input => \@pickup_input) : (),
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

        $self->client_simple->disconnect();
    }
    catch ($err) {
        $self->log->error("Unable to query OpenAPI specification from OpenXPKI server: $err");
        return;
    }

    return $openapi_spec;

}

__PACKAGE__->meta->make_immutable;

__END__;
