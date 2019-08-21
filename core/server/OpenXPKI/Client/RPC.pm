package OpenXPKI::Client::RPC;

use Moose;
use warnings;
use strict;
use Carp;
use English;
use OpenXPKI::Client::Simple;

has config => (
    is      => 'rw',
    isa     => 'Object',
    required => 1,
);

has backend => (
    is      => 'rw',
    isa     => 'Object|Undef',
    lazy => 1,
    builder => '_init_backend',
);

sub _init_backend {

    my $self = shift;
    my $config = $self->config();
    my $conf = $config->config();

    return OpenXPKI::Client::Simple->new({
        logger => $config->logger(),
        config => $conf->{global}, # realm and locale
        auth => $conf->{auth}, # auth config
    });

}


sub openapi_spec {

    my $self = shift;
    my $openapi_server_url = shift;
    my $conf = $self->config()->config();

    my $openapi_spec = {
        openapi => "3.0.0",
        info => { title => "OpenXPKI RPC API", version => "0.0.1", description => "Run a defined set of OpenXPKI workflows" },
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
                                'code' => { type => 'integer', },
                                'message' => { type => 'string', },
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

    my $paths;
    eval {
        my $client = $self->backend() or die "Could not create OpenXPKI client";

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
