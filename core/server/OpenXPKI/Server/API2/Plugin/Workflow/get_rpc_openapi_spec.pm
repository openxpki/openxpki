package OpenXPKI::Server::API2::Plugin::Workflow::get_rpc_openapi_spec;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_rpc_openapi_spec

=cut

# Project modules
use OpenXPKI::Client::Config;
use OpenXPKI::Connector::WorkflowContext;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;


our %TYPE_MAP = (
    server      => 'string',
    text        => 'string',
    uploadarea  => 'string',
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

Restrictions:

=over

=item *

=back




B<Parameters>

=over

=item * C<workflow> I<Str> - workflow type

=back

=cut
command "get_rpc_openapi_spec" => {
    workflow => { isa => 'Str', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $type = $params->workflow;
    my $rpc_conf = OpenXPKI::Client::Config->new('rpc');



    if (not $self->factory->authorize_workflow({ ACTION => 'create', TYPE => $type })) {
        OpenXPKI::Exception->throw(
            message => 'User is not authorized to fetch workflow info',
            params => { type => $type }
        );
    }

    my $head = CTX('config')->get_hash([ 'workflow', 'def', $type, 'head' ]);
    my $result = {
        type        => $type,
        label       => $head->{label},
        description => $head->{description},
    };

    my $fields = $self->_get_fields($type, 'INITIAL');

    # map OpenXPKI to OpenAPI types
    for my $field (values %$fields) {
        $field->{type} = $OpenXPKI::Server::API2::Plugin::Workflow::get_rpc_openapi_spec::TYPE_MAP{$field->{type}}
            or OpenXPKI::Exception->throw(
                message => 'Field type found that has no mapping to OpenAPI type',
                params => { field_type => $field->{type} }
            );
    }

    return $fields;
};

# Returns a HashRef with field names and their definition
sub _get_fields {
    my ($self, $type, $query_state) = @_;

    my $result = {};
    my $wf_config = $self->factory->_get_workflow_config($type);

    #
    # fetch actions in state $query_state from the config
    #
    my @actions = ();

    # get name of first action of $query_state
    my $first_action;
    for my $state (@{$wf_config->{state}}) {
        if ($state->{name} eq $query_state) {
            $first_action = $state->{action}->[0]->{name} ;
            last;
        }
    }
    OpenXPKI::Exception->throw(
        message => 'State not found in workflow',
        params => { workflow_type => $type, state => $query_state }
    ) unless $first_action;

    push @actions, $first_action;

    # get names of further actions in $query_state
    # TODO This depends on the internal naming of follow up actions in Workflow.
    #      Alternatively we could parse actions again as in OpenXPKI::Server::API2::Plugin::Workflow::Util->_get_config_details which is also not very elegant
    my $followup_state_re = sprintf '^%s_%s_\d+$', $query_state, uc($first_action);
    for my $state (@{$wf_config->{state}}) {
        if ($state->{name} =~ qr/$followup_state_re/) {
            push @actions, $state->{action}->[0]->{name} ;
        }
    }

    # get field informations
    for my $action (@actions) {
        my $action_info = $self->factory->get_action_info($action, $type);
        my $fields = $action_info->{field};
        $result->{$_->{name}} = $_ for @$fields;
        $result->{$_->{name}}->{action} = $action;
    }

    return $result;
}

__PACKAGE__->meta->make_immutable;
