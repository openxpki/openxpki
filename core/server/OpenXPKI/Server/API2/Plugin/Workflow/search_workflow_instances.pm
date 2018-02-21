package OpenXPKI::Server::API2::Plugin::Workflow::search_workflow_instances;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::search_workflow_instances

=cut

# CPAN modules
use Moose::Util::TypeConstraints;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;


subtype 'ArrayOrAlphaPunct',
    as 'ArrayRef[AlphaPunct]';

coerce 'ArrayOrAlphaPunct',
    from 'AlphaPunct',
    via { [ $_ ] };


=head1 COMMANDS

=head2 search_workflow_instances

Searches workflow instances using the given parameters and returns an I<ArrayRef>
of I<HashRefs>:

    {
        'pki_realm' => 'alpha',
        'workflow_id' => '74751',
        'workflow_last_update' => '2018-02-10 00:58:36',
        'workflow_proc_state' => 'finished',
        'workflow_state' => 'SUCCESS',
        'workflow_type' => 'wf_type_1',
        'workflow_wakeup_at' => '0'
    }

B<Parameters>

=over

=item * C<check_acl> I<Bool> - set to 1 to only return workflow that the current user is allowed to access. Default: 0

=item * C<pki_realm> I<Str> - PKI realm

=item * C<id> I<ArrayRef> - list of workflow IDs

=item * C<type> I<ArrayRef|Str> - type

=item * C<state> I<ArrayRef|Str> - state

=item * C<proc_state> I<Str> - processing state

=item * C<attribute> I<HashRef> - key is attribute name, value is passed
"as is" as where statement on value, see documentation of SQL::Abstract.

Legacy: I<ArrayRef> - attribute values (legacy search syntax)

=item * C<limit> I<Int> - limit results

=item * C<start> I<Int> - offset results by this (allows for paging)

=item * C<order> I<Str> - column name to order by. Default: I<workflow_id>

=item * C<reverse> I<Bool> - set to 1 for reverse ordering (ascending). Default: descending

=back

=cut
command "search_workflow_instances" => {
    pki_realm  => { isa => 'AlphaPunct', },
    id         => { isa => 'ArrayRef', },
    type       => { isa => 'ArrayOrAlphaPunct', coerce => 1, },
    state      => { isa => 'ArrayOrAlphaPunct', coerce => 1, },
    proc_state => { isa => 'AlphaPunct', },
    attribute  => { isa => 'ArrayRef|HashRef', },
    start      => { isa => 'Int', },
    limit      => { isa => 'Int', },
    order      => { isa => 'Str', },
    reverse    => { isa => 'Bool', },
    check_acl  => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    my %sql_params = (
        %{ $self->_search_query_params($params) },
        %{ $self->_search_query_params_exclusive($params) },
    );
    my $result = CTX('dbi')->select(
        %sql_params,
        columns => [ qw(
            workflow_last_update
            workflow.workflow_id
            workflow_type
            workflow_state
            workflow_proc_state
            workflow_wakeup_at
            pki_realm
        ) ],
    )->fetchall_arrayref({});

    # check_acl: only return items that the user can access
    if ($params->check_acl) {
        my $factory = CTX('workflow_factory')->get_factory;
        # FIXME This does not work for "self" and "other" ACL checks: second parameter to check_acl() must be creator!
        $result = [ grep { $factory->check_acl($_->{workflow_type}, $_->{workflow_id}) } @$result ];
    }

    return $result;
};

=head2 search_workflow_instances_count

Searches workflow instances using the given parameters and returns the number
of workflows found.

see search_workflow_instances, limit and order fields are not applicable.

=back

=cut
command "search_workflow_instances_count" => {
    pki_realm  => { isa => 'AlphaPunct', },
    id         => { isa => 'ArrayRef', },
    type       => { isa => 'ArrayOrAlphaPunct', coerce => 1, },
    state      => { isa => 'ArrayOrAlphaPunct', coerce => 1, },
    proc_state => { isa => 'AlphaPunct', },
    attribute  => { isa => 'ArrayRef|HashRef', },
} => sub {
    my ($self, $params) = @_;

    my $sql_params = $self->_search_query_params($params);
    my $result = CTX('dbi')->select_one(
        %{ $sql_params },
        columns => [ 'COUNT(workflow.workflow_id)|amount' ],
    );

    ##! 1: "finished"
    return $result->{amount};
};

sub _search_query_params {
    my ($self, $args) = @_;

    my $re_alpha_string = qr{ \A [ \w \- \. : \s ]* \z }xms;

    my $where = {};
    my $params = {
        where => $where,
    };

    # Search for known serials, used e.g. for certificate relations
    $where->{'workflow.workflow_id'} = $args->id if $args->has_id;

    my @join_spec = ();
    if ( $args->has_attribute ) {

        # we need to join over the workflow_attributes table
        my $ii = 0;
        # Legacy API
        if (ref $args->attribute eq 'ARRAY') {

            for my $cond (@{$args->attribute}) {
                ##! 16: 'certificate attribute: ' . Dumper $cond
                my $table_alias = "workflowattr$ii";

                # add join table
                push @join_spec, ( 'workflow.workflow_id=workflow_id', "workflow_attributes|$table_alias" );

                # add search constraint
                $where->{ "$table_alias.attribute_contentkey" } = $cond->{KEY};

                $cond->{OPERATOR} //= 'EQUAL';
                # sanitize wildcards (don't overdo it...)
                if ($cond->{OPERATOR} eq 'LIKE') {
                    $cond->{VALUE} =~ s/\*/%/g;
                    $cond->{VALUE} =~ s/%%+/%/g;
                }
                # TODO #legacydb search_workflow_instances' ATTRIBUTE allows old DB layer syntax
                $where->{ "$table_alias.attribute_value" } =
                    OpenXPKI::Server::Database::Legacy->convert_dynamic_cond($cond);

                $ii++;
            }
        } else {

            foreach my $key (keys %{$args->attribute}) {

                my $table_alias = "workflowattr$ii";

                # add join table
                push @join_spec, ( 'workflow.workflow_id=workflow_id', "workflow_attributes|$table_alias" );

                # add search constraint
                $where->{ "$table_alias.attribute_contentkey" } = $key;
                $where->{ "$table_alias.attribute_value" } = $args->attribute->{$key};
                $ii++;

            }

        }
    }

    if (scalar @join_spec) {
        $params->{from_join} = join " ", 'workflow', @join_spec;
    }
    else {
        $params->{from} = 'workflow',
    }

    # Do not restrict if PKI_REALM => "_any"
    if (not $args->has_pki_realm or $args->pki_realm !~ /_any/i) {
        $where->{pki_realm} = $args->pki_realm // CTX('session')->data->pki_realm;
    }

    $where->{workflow_type} = $args->type if $args->has_type;
    $where->{workflow_state} = $args->state if $args->has_state;
    $where->{workflow_proc_state} = $args->proc_state if $args->has_proc_state;

    ##! 32: 'params: ' . Dumper $params
    return $params;
}

sub _search_query_params_exclusive {
    my ($self, $args) = @_;

    my $params = {};

    if ($args->has_limit ) {
        $params->{limit} = $args->limit;
        $params->{offset} = $args->start if $args->has_start;
    }

    # Custom ordering
    my $desc = "-"; # not set or 0 means: DESCENDING, i.e. "-"
    $desc = "" if $args->has_reverse and $args->reverse == 0;
    my $order = $args->has_order ? $args->order : 'workflow_id';
    $params->{order_by} = sprintf "%s%s", $desc, $order;

    return $params;
}

__PACKAGE__->meta->make_immutable;
