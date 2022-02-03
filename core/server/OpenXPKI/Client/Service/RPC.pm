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

has config => (
    is      => 'rw',
    isa     => 'Object',
    required => 1,
);

has error_messages => (
    is      => 'rw',
    isa     => 'HashRef',
    required => 1,
);

has backend => (
    is      => 'rw',
    isa     => 'Object|Undef',
    lazy => 1,
    builder => '_init_backend',
);

has logger => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    default  => sub { my $self = shift; return $self->config()->logger() },
);

sub _init_backend {

    my $self = shift;
    my $config = $self->config();
    my $conf = $config->config();

    return OpenXPKI::Client::Simple->new({
        logger => $self->logger(),
        config => $conf->{global}, # realm and locale
        auth => $conf->{auth} || {}, # auth config
    });

}

sub openapi_spec {

    my $self = shift;
    my $openapi_server_url = shift;
    my $conf = $self->config()->config();

    my $info = { title => "OpenXPKI RPC API" };
    if (my $api_info = $conf->{openapi}) {
        $info = { %$info, %$api_info };
    }

    my $openapi_spec = {
        openapi => "3.0.0",
        info => $info,
        servers => [ { url => $openapi_server_url, description => "OpenXPKI server" } ],
        components => {
            schemas => {
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
            },
        },
    };

    my $paths = {};
    eval {
        my $client = $self->backend() or die "Could not create OpenXPKI client";

        if (!$openapi_spec->{info}->{version}) {
            my $server_version = $client->run_command('version');
            $openapi_spec->{info}->{version} = $server_version->{config}->{api} || 'unknown';
        }

        for my $method (sort keys %$conf) {
            next unless ($conf->{$method}->{workflow});
            my $in = $conf->{$method}->{param} || '';
            my $out = $conf->{$method}->{output} || '';
            my $method_spec = $client->run_command('get_rpc_openapi_spec', {
                workflow => $conf->{$method}->{workflow},
                input => [ split /\s*,\s*/, $in ],
                output => [ split /\s*,\s*/, $out ]
            });

            $paths->{"/$method"} = {
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
                    responses => {
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
                    },
                },
            };
        }

        $client->disconnect();
    };
    if (my $eval_err = $EVAL_ERROR) {
        $self->logger()->error("Unable to query OpenAPI specification from OpenXPKI server: $eval_err");
        return;
    }

    $openapi_spec->{paths} = $paths;
    return $openapi_spec;

}

1;

__END__;
