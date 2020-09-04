package OpenXPKI::Client::RPC;

use Moose;
use warnings;
use strict;
use Carp;
use English;
use Data::Dumper;
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
        auth => $conf->{auth} || {}, # auth config
    });

}

sub pickup_workflow {

    my $self = shift;
    # the hash from the config section of this method
    my $config = shift;
    my $pickup_value = shift;

    my $workflow_type = $config->{workflow};
    my $client = $self->backend();
    my $wf_id;
    if (my $wf_type = $config->{pickup_workflow}) {

        $client->logger()->debug("Pickup via workflow $wf_type with keys " . join(",", keys %{$pickup_value}));
        my $result = $client->handle_workflow({
            type => $wf_type,
            params => $pickup_value,
        });

        die "No result from pickup workflow" unless($result->{context});
        $client->logger()->trace("Pickup workflow result: " . Dumper $result) if ($client->logger()->is_trace);

        $wf_id = $result->{context}->{workflow_id};

    } elsif ($config->{pickup_namespace}) {

        $client->logger()->debug("Pickup via datapool with $config->{pickup_namespace} => $pickup_value" );
        my $wfl = $client->run_command('get_data_pool_entry', {
            namespace => $config->{pickup_namespace},
            key => $pickup_value,
        });
        if ($wfl->{value}) {
            $wf_id = $wfl->{value};
        }

    } else {
        # pickup from workflow with explicit attribute name or key name
        my $pickup_key = $config->{pickup_attribute} || $config->{pickup};

        $client->logger()->debug("Pickup via attribute with $pickup_key => $pickup_value" );
        my $wfl = $client->run_command('search_workflow_instances', {
            type => $workflow_type,
            attribute => { $pickup_key => $pickup_value },
            limit => 2
        });

        if (@$wfl > 1) {
            die "Unable to pickup workflow - ambigous search result";
        } elsif (@$wfl == 1) {
            $wf_id = $wfl->[0]->{workflow_id};
        }
    }

    if (!$wf_id) {
        $client->logger()->trace("No pickup as no result found");
        return unless ($wf_id);
    }

    if (ref $wf_id || $wf_id !~ m{\A\d+\z}) {
        $client->logger()->error("Pickup result is not an integer number!");
        $client->logger()->trace(Dumper $wf_id) if ($client->logger()->is_trace());
        return;
    }

    $client->logger()->debug("Pickup $wf_id for " . (ref $pickup_value ? (join " ,", values %{$pickup_value}) : $pickup_value));
    return $client->handle_workflow({
        id => $wf_id,
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
        $self->backend()->logger()->error("Unable to query OpenAPI specification from OpenXPKI server: $eval_err");
        return;
    }

    $openapi_spec->{paths} = $paths;
    return $openapi_spec;

}

1;

__END__;
