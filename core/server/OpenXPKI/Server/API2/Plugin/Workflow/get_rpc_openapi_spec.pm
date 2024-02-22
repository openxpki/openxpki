package OpenXPKI::Server::API2::Plugin::Workflow::get_rpc_openapi_spec;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_rpc_openapi_spec

=cut

# Core modules
use List::Util;

# CPAN modules
use JSON;
use Type::Params qw( signature_for );

# Project modules
use OpenXPKI::i18n qw( i18nGettext );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;

# should be done after imports to safely disable warnings in Perl < 5.36
use experimental 'signatures';

# Sources for "type" and "format" (subtype):
#   OpenXPKI::Client::UI::Workflow->__render_fields()
#   https://openxpki.readthedocs.io/en/latest/reference/developer/webui.html?highlight=rawlist#formattet-strings-string-format

our %FORMAT_MAP = (
    ullist => { type => 'array' },
    rawlist => { type => 'array' },
    deflist => { type => 'array' },
    cert_info => { _hint => 'if prefixed with "OXJSF1:" it is a JSON string.', },
    # FIXME: use enum from OpenXPKI::Server::API2::Types
    certstatus => { type => 'string', enum => [ qw( ISSUED REVOKED CRL_ISSUANCE_PENDING EXPIRED ) ] },
);

our %TYPE_MAP = (
    bool => { type => 'boolean' },
    text => { type => 'string' },
    datetime => { type => 'integer', minimum => 0 },
    uploadarea => { type => 'string', format => 'binary' },
    select => { type => 'string' },
    server => { type => 'string' },
    cert_identifier => { type => 'string' },
    cert_subject => { type => 'string' },
    cert_info => { type => 'string' },
    password => { type => 'string', format => 'password' },
    passwordverify => { type => 'string', format => 'password' },
);

our %KEY_MAP = (
    pkcs10 => { _hint => 'if prefixed with "OXJSF1:" it is a JSON string.', },
    pkcs7 => { _hint => 'if prefixed with "OXJSF1:" it is a JSON string.', },
    match => { type => 'string' },
);


has factory => (
    is => 'rw',
    isa => 'OpenXPKI::Workflow::Factory',
    lazy => 1,
    default => sub { CTX('workflow_factory')->get_factory },
);

=head1 COMMANDS

=head2 get_rpc_openapi_spec

Returns the OpenAPI specification for the given workflow.

B<Parameters>

=over

=item * C<rpc_method> I<Str> - name of the RPC method

=item * C<workflow> I<Str> - workflow type

=item * C<input> I<ArrayRef> - filter for input parameters (list of allowed parameters)

=item * C<output> I<ArrayRef> - filter for output parameters (list of allowed parameters)

=item * C<pickup_workflow> I<Str> - workflow type of the pickup workflow

=item * C<pickup_input> I<ArrayRef> - filter for input parameters for the pickup workflow (list of allowed parameters)

=back

=cut
command "get_rpc_openapi_spec" => {
    rpc_method => { isa => 'Str', required => 1, },
    workflow => { isa => 'Str', required => 1, },
    action => { isa => 'Str', required => 0, },
    input => { isa => 'ArrayRef[Str]', required => 0, default => sub { [] } },
    output => { isa => 'ArrayRef[Str]', required => 0, default => sub { [] } },
    pickup_workflow => { isa => 'Str', required => 0, },
    pickup_input => { isa => 'ArrayRef[Str]', required => 0, default => sub { [] } },
} => sub {
    my ($self, $params) = @_;

    my $workflow = $params->workflow;

    # details for "workflow" and "input"
    my ($descr, $input_schema) = $self->_get_workflow_info(
        workflow => $params->workflow,
        input_params => $params->input,
        $params->has_action ? (custom_action => $params->action) : (),
    );

    # details for "pickup_workflow" and "pickup_input"
    my $pickup_input_schema;
    if ($params->has_pickup_workflow) {
        (undef, $pickup_input_schema) = $self->_get_workflow_info(
            workflow => $params->pickup_workflow,
            input_params => $params->pickup_input,
            is_pickup_workflow => 1,
        );
    # input without workflow -> single parameter of type string
    } elsif ($params->pickup_input->@*) {
        $pickup_input_schema = {
            properties => {
                $params->pickup_input->[0] => {
                    type => 'string'
                }
            }
        };
    }

    # get field info for all output fields
    # (note that currently there is no way to statically check if the output fields
    # specified in the RPC config will actually exist in the workflow context)
    my $output = {
        map { $_->{name} => $_ }                                # field name => info hash
        map { $self->factory->get_field_info($_, $params->workflow) }   # info hash about field
        @{ $params->output }                                    # output field names
    };

    my $result = {
        description => $descr,
        output_schema => $self->_openapi_field_schema(
            workflow => $params->workflow,
            wf_fields => $output,
            rpc_spec_field_names => $params->output,
        ),
        components => {},
    };


    # Pickup and resume case - parameters for BOTH workflows are required
    if ($params->has_action) {
        my $method = $params->rpc_method;
        # The resume action has parameters so we need to provide two schemata
        if (keys $input_schema->{properties}->%*) {
            $result->{input_schema} = {
                allOf => [
                    $pickup_input_schema,
                    { '$ref' => "#/components/schemas/${method}Body" },
                ],
                # we should have a verbose title here for the action
                title => "Pickup and Resume Workflow",
            };
            $result->{components}->{schemas} = {
                "${method}Body" => {
                    $input_schema->%*,
                    title => "New workflow",
                },
            };
        # The resume action has no params so we need only the pickup params
        } else {
            $result->{input_schema} = {
                $pickup_input_schema->%*,
                title => "Pickup and Resume Workflow",
            };
        }

    # Pickup or create - we expect that both need parameters
    # (there might be edge cases) where this is not true
    } elsif ($pickup_input_schema) {
        my $method = $params->rpc_method;
        $result->{input_schema} = {
            oneOf => [
                { '$ref' => "#/components/schemas/${method}Body" },
                {
                    allOf => [
                        $pickup_input_schema,
                        { '$ref' => "#/components/schemas/${method}Body" },
                    ],
                    title => "Pickup Workflow",
                },
            ],
        };
        $result->{components}->{schemas} = {
            "${method}Body" => {
                $input_schema->%*,
                title => "Create workflow",
            },
        };
    # omit request body definitons if workflow has no params
    } elsif (keys $input_schema->{properties}->%*) {
        $result->{input_schema} = {
            $input_schema->%*,
            title => "Create workflow",
        };
    }

    return $result;
};

signature_for _get_workflow_info => (
    method => 1,
    named => [
        workflow => 'Str',
        input_params => 'ArrayRef',
        custom_action => 'Str', { optional => 1 },
        is_pickup_workflow => 'Bool', { optional => 1, default => 0 },
    ],
);
sub _get_workflow_info ($self, $arg) {
    if (not $self->factory->can_create_workflow( $arg->workflow )) {
        OpenXPKI::Exception->throw(
            message => 'User is not authorized to fetch workflow info',
            params => { workflow => $arg->workflow }
        );
    }

    my $head = CTX('config')->get_hash([ 'workflow', 'def', $arg->workflow, 'head' ]);

    my $action;
    if ($arg->custom_action) {
        $action = $arg->custom_action;
        my $prefix = $head->{prefix};
        if ($action !~ qr/\A(global|$prefix)_/) {
            $action = $prefix.'_'.$action;
        }
    } else {
        # fetch actions in state INITIAL from the config
        my $wf_config = $self->factory->_get_workflow_config($arg->workflow);
        for my $state (@{$wf_config->{state}}) {
            next unless $state->{name} eq 'INITIAL';
            ($action) = map { $_->{name} } @{$state->{action}};
            last;
        }
        OpenXPKI::Exception->throw(
            message => 'No INITIAL action found in workflow',
            params => { workflow_type => $arg->workflow }
        ) unless $action;
    }

    my $descr = $head->{description} ? i18nGettext($head->{description}) : $arg->workflow;

    return (
        # description
        $descr,
        # input schema
        $self->_openapi_field_schema(
            workflow => $arg->workflow,
            wf_fields => $self->_get_input_fields($arg->workflow, $action),
            rpc_spec_field_names => $arg->input_params,
            $arg->is_pickup_workflow ? (prefix => 'Workflow pickup: ') : (),
        ),
    );
}

# ... this also filters out fields that are requested but do not exist in the workflow
signature_for _openapi_field_schema => (
    method => 1,
    named => [
        workflow => 'Str',
        wf_fields => 'HashRef',
        rpc_spec_field_names => 'ArrayRef',
        prefix => 'Str', { optional => 1, default => '' },
    ],
);
sub _openapi_field_schema ($self, $arg) {
    my $workflow = $arg->workflow;

    my $field_specs = {}; # HashRef { fieldname => { type => ... }, fieldname => ... }
    my @required_fields;
    my @missing_fields;

    # skip fields defined in RPC spec but not available in workflow
    for my $fieldname ($arg->rpc_spec_field_names->@*) {
        if (not $arg->wf_fields->{$fieldname}) {
            CTX('log')->system->warn("Parameter '$fieldname' as requested for OpenAPI spec is not defined in workflow '$workflow'");
            next;
        }
        my $wf_field = $arg->wf_fields->{$fieldname};

        # remember required fields as they have to be listed outside the field specification
        push @required_fields, $fieldname if $wf_field->{required};

        my $field = {};
        my @hints = ();

        #
        # 1) try to detect OpenXPKI's "format" and/or "type" to set (any or all of):
        #  - type
        #  - description
        #  - format
        #  - enum
        # etc.
        #

        # TODO: Handle select fields (check if options are specified)

        # map OpenXPKI to OpenAPI types
        my $internal_type = $wf_field->{type}; # variable used in exception

        # add "format" specific OpenAPI attributes
        my $match = $FORMAT_MAP{ $wf_field->{format} // "" };
        if ($match) {
            push @hints, delete $match->{_hint} if $match->{_hint};
            $field = { %$field, %$match };
        }

        # add "type" specific OpenAPI attributes
        $match = $TYPE_MAP{ $wf_field->{type} // "" };
        if ($match) {
            push @hints, delete $match->{_hint} if $match->{_hint};
            $field = { %$field, %$match };
        }

        # add fieldname specific OpenAPI attributes
        $match = $KEY_MAP{ $fieldname };
        if ($match) {
            push @hints, delete $match->{_hint} if $match->{_hint};
            $field = { %$field, %$match };
        }

        # SELECT fields
        if ($wf_field->{option}) {
            $field->{enum} = [ map { $_->{value} } @{ $wf_field->{option} } ];
        }

        # field contains regular expression
        if ($wf_field->{match}) {
            if ($wf_field->{ecma_match}) {
                $field->{type} = 'string';
                $field->{pattern} = $wf_field->{ecma_match};
            }
            else {
                push @hints, 'String must match the Perl regex /'.$wf_field->{match}.'/msx .';
            }
        }

        if (not scalar keys %$field) {
            push @missing_fields, $wf_field->{name};
            $field = { type => 'unknown' };
        }

        # special handling for multivalue fields:
        # they are represented as Arrays of values of their specified type
        if (defined $wf_field->{min} or $wf_field->{max}) {
            $field = {
                type => 'array',
                items => $field,
            }
        }

        #
        # 2) use OpenAPI type spec if provided to set/overwrite:
        #  - type
        #  - properties
        #  - decription
        #
        if ($wf_field->{api_type}) {
            $field = {
                %$field,
                %{ $self->api->get_openapi_typespec(spec => $wf_field->{api_type}) },
            };
            # use API specific label if provided
            $field->{description} = i18nGettext($wf_field->{api_label}) if $wf_field->{api_label};
        }

        # if not already set, use UI label as description (must be non-empty by OpenAPI spec)
        $field->{description} //= $wf_field->{label} ? i18nGettext($wf_field->{label}) : $fieldname;

        # add hints to description
        $field->{description} .= ' ('.join(' ', @hints).')' if scalar @hints;

        # prefix description
        $field->{description} = $arg->prefix . $field->{description};

        # Consistency checks - should be a critical problem
        if ($field->{pattern} and $field->{enum}) {
            CTX('log')->system()->warn("Inconsistency found: enum/select field has additional match rule in $workflow / $fieldname");
            delete $field->{pattern};
        }

        $field_specs->{$fieldname} = $field;
    }

    if (@missing_fields) {
        CTX('log')->system()->warn("Missing definitions for OpenAPI spec for $workflow / ".join(", ", @missing_fields));
    }

    return {
        type => 'object',
        properties => $field_specs,
        @required_fields ? (required => \@required_fields) : (),
    };
}

# Returns a HashRef with field names and their definition
sub _get_input_fields {
    my ($self, $workflow, $action) = @_;

    my $result = {};

    my $action_info = $self->factory->get_action_info($action, $workflow);
    my $fields = $action_info->{field};
    for my $f (@$fields) {
        $result->{$f->{name}} = {
            %$f,
            action => $action
        };
    }
    return $result;
}

__PACKAGE__->meta->make_immutable;
