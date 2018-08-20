package OpenXPKI::Server::API2::Plugin::Workflow::search_workflow_instances;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::search_workflow_instances

=cut

# CPAN modules
use Data::Dumper;
use Moose::Util::TypeConstraints;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;


subtype 'ArrayOrAlphaPunct',
    as 'ArrayRef[AlphaPunct]';

coerce 'ArrayOrAlphaPunct',
    from 'AlphaPunct',
    via { [ $_ ] };

# helper / cache: maps each (queried) workflow type to the ACL defined for the current user's role
has 'acl_by_wftype' => (
    isa => 'HashRef',
    is => 'rw',
    default => sub { {} },
);

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

=item * C<return_attributes> I<ArrayRef> - add the given attributes as
columns to the result set. Each attribute is added as extra column
using the attribute name as key.

=back

=cut
command "search_workflow_instances" => {
    pki_realm  => { isa => 'AlphaPunct', },
    id         => { isa => 'ArrayRef', },
    type       => { isa => 'ArrayOrAlphaPunct', coerce => 1, },
    state      => { isa => 'ArrayOrAlphaPunct', coerce => 1, },
    proc_state => { isa => 'AlphaPunct', },
    attribute  => { isa => 'ArrayRef|HashRef', default => sub { {} } },
    start      => { isa => 'Int', },
    limit      => { isa => 'Int', },
    order      => { isa => 'Str', },
    reverse    => { isa => 'Bool', },
    check_acl  => { isa => 'Bool', default => 0 },
    return_attributes => {isa => 'ArrayRef', default => sub { [] } },
} => sub {
    my ($self, $params) = @_;

    # build db query parameters
    my %sql_params = (
        %{ $self->_search_query_params($params, $params->check_acl) },
        %{ $self->_search_query_params_exclusive($params) },
    );

    # run SELECT query
    my $result = CTX('dbi')->select(
        %sql_params,
    )->fetchall_arrayref({});

    # ACLs part 3: filter result by applying ACL checks of type regex
    if ($params->check_acl) {
        $result = [ grep {
            my $acl = $self->acl_by_wftype->{ $_->{workflow_type} };
            $acl !~ /^(any|self|others)$/    # ACL of type regex?
                ? $_->{creator} =~ qr/$acl/  # --> apply it
                : 1
        } @$result ];
    }

    return $result;
};

=head2 search_workflow_instances_count

Searches workflow instances using the given parameters and returns the number
of workflows found.

see search_workflow_instances, limit and order fields are not applicable.

=cut
command "search_workflow_instances_count" => {
    pki_realm  => { isa => 'AlphaPunct', },
    id         => { isa => 'ArrayRef', },
    type       => { isa => 'ArrayOrAlphaPunct', coerce => 1, },
    state      => { isa => 'ArrayOrAlphaPunct', coerce => 1, },
    proc_state => { isa => 'AlphaPunct', },
    attribute  => { isa => 'ArrayRef|HashRef', },
    return_attributes => {isa => 'ArrayRef', },
} => sub {
    my ($self, $params) = @_;

    $params->return_attributes([]);

    my $sql_params = $self->_search_query_params($params, 0);
    my $result = CTX('dbi')->select_one(
        %{ $sql_params },
        columns => [ 'COUNT(workflow.workflow_id)|amount' ],
    );

    ##! 1: "finished"
    return $result->{amount};
};

sub _search_query_params {
    my ($self, $args, $check_acl) = @_;

    my $re_alpha_string = qr{ \A [ \w \- \. : \s ]* \z }xms;

    my $where = {};
    my $params = {
        where => $where,
        columns => [ qw(
            workflow_last_update
            workflow.workflow_id
            workflow_type
            workflow_state
            workflow_proc_state
            workflow_wakeup_at
            pki_realm
        ) ],
    };

    ##! 16: 'Input args ' . Dumper $args

    #
    # ACLs part 1: filter out workflow types with undefined ACLs (= no access)
    #
    my $user;
    if ($check_acl) {
        $user = CTX('session')->data->user;
        my $role = CTX('session')->data->has_role ? CTX('session')->data->role : 'Anonymous';

        my @wf_types_to_check = $args->has_type
            ? @{ $args->type } # if specified, only query given workflow types ('type' param is always an ArrayRef)
            : CTX('config')->get_keys([ 'workflow', 'def' ]); # otherwise: query all types

        my @include_wf_types = ();
        my %role_acl_by_wftype = ();
        my $add_creator = 0; # only join workflow_attributes table if neccessary

        for my $type (@wf_types_to_check) {
            my $creator_acl = CTX('config')->get([ 'workflow', 'def', $type, 'acl', $role, 'creator' ]);

            # do not query workflow types if there's no ACL (i.e. no access) for the current user's role
            next unless $creator_acl;

            push @include_wf_types, $type;

            # store ACLs:
            # 1. as a cache for the other for-loop below that inserts WHERE clauses
            # 2. to remember ACLs of type "RegEx" where checks have to be done after the SQL query
            $self->acl_by_wftype->{$type} = $creator_acl;

            # add 'creator' column to be able to filter on it using WHERE later on
            $add_creator = 1 if $creator_acl ne 'any'; # 'any': no restriction - user may see all workflows
        }

        # add the "creator" column
        push @{ $args->return_attributes }, 'creator' if $add_creator;

        # filter by workflow type
        $where->{workflow_type} = \@include_wf_types;
    }
    else {
        $where->{workflow_type} = $args->type if $args->has_type;
    }

    #
    # helper to make sure an SQL JOIN is added for each attribute
    #
    my $return_attrib = {};
    if ($args->has_return_attributes) {
        map { $return_attrib->{$_} = '' } @{$args->return_attributes};
    }

    #
    # add JOINs for each attribute filter parameter
    #
    my @join_spec = ();
    my %attr_value_colspec = (); # map: joined attribute's name => full table.column spec of attribute value
    my $ii = 0;
    if ( $args->has_attribute ) {
        # we need to join over the workflow_attributes table

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
                $attr_value_colspec{$key} = "$table_alias.attribute_value";
                $ii++;

                # if the attribute should be returned we add the table name used
                $return_attrib->{$key} = $table_alias if (defined $return_attrib->{$key});

            }

        }
    }

    ##! 64: 'return_attrib ' . Dumper $return_attrib

    #
    # add all requested attributes as columns
    #
    foreach my $key (keys %{$return_attrib}) {
        # if the attribute was used in the attribute filter above, it is already joined
        my $table_alias = $return_attrib->{$key};

        if (!$table_alias) {
            $table_alias = "workflowattr$ii";
            # outer join to also get empty values
            push @join_spec, ( "=>workflow.workflow_id=workflow_id=identifier,$table_alias.attribute_contentkey='$key'", "workflow_attributes|$table_alias" );
            $attr_value_colspec{$key} = "$table_alias.attribute_value";
            $ii++;
        }
        push @{$params->{columns}}, "$table_alias.attribute_value as $key";
    }

    #
    # final step of JOIN definitions
    #
    if (scalar @join_spec) {
        $params->{from_join} = join " ", 'workflow', @join_spec;
    }
    else {
        $params->{from} = 'workflow',
    }

    #
    # ACLs part 2: filter by 'creator'
    #
    if ($check_acl) {
        my @where_additions = ();
        for my $type (keys %{ $self->acl_by_wftype }) {
            my $acl = $self->acl_by_wftype->{$type};
            my $creator_col = $attr_value_colspec{'creator'};
            # 'self': users may see their own workflows
            if ('self' eq $acl) {
                push @where_additions, { 'workflow_type' => $type, $creator_col => $user };
            }
            # 'others': users may only see workflow of other users (not their own)
            elsif ('others' eq $acl) {
                push @where_additions, { 'workflow_type' => $type, $creator_col => { '!=', $user } };
            }
            # interpret anything else as a regex pattern: creator is filtered AFTER the SQL query
            else {
                push @where_additions, { 'workflow_type' => $type };
            }
        }

        # redefine WHERE clause so that the $where conditions set up so far form
        # one of two AND connected parts
        $params->{where} = {
            -and => [
                $where,
                -or => \@where_additions,
            ],
        };
    }

    # Search for known serials, used e.g. for certificate relations
    $where->{'workflow.workflow_id'} = $args->id if $args->has_id;

    # Do not restrict if PKI_REALM => "_any"
    if (not $args->has_pki_realm or $args->pki_realm !~ /_any/i) {
        $where->{pki_realm} = $args->pki_realm // CTX('session')->data->pki_realm;
    }

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
