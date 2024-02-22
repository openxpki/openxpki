package OpenXPKI::Client::Service::RPC;
use Moose;

with 'OpenXPKI::Client::Service::Role::PickupWorkflow';

# Core modules
use Carp;
use English;
use Data::Dumper;

# CPAN modules
use JSON;

# Project modules
use OpenXPKI::Client::Simple;

# Feature::Compat::Try should be done last to safely disable warnings
use Feature::Compat::Try;


has config_obj => (
    is => 'rw',
    isa => 'OpenXPKI::Client::Config',
    required => 1,
);

has endpoint => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

# the endpoint config
has config => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    init_arg => undef,
    default => sub { $_[0]->config_obj->endpoint_config($_[0]->endpoint) },
);

has error_messages => (
    is      => 'rw',
    isa     => 'HashRef',
    required => 1,
);

has logger => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    init_arg => undef,
    default => sub { $_[0]->config_obj->logger },
);

has backend => (
    is      => 'rw',
    isa     => 'Object|Undef',
    lazy => 1,
    builder => '_init_backend',
);

sub _init_backend {

    my $self = shift;
    my $conf = $self->config;

    return OpenXPKI::Client::Simple->new({
        logger => $self->logger,
        config => $conf->{global}, # realm and locale
        auth => $conf->{auth} || {}, # auth config
    });

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
                                . join("\n", map { " * $_ - ".$self->error_messages->{$_} } sort keys %{ $self->error_messages }),
                            enum => [ map { $_+0 } sort keys %{ $self->error_messages } ],
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
        $self->logger->error("Unable to query OpenAPI specification from OpenXPKI server: $err");
        return;
    }

    return $openapi_spec;

}

__PACKAGE__->meta->make_immutable;

__END__;
