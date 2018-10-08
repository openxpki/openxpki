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

has 'count_only' => (
    isa => 'Bool',
    is => 'rw',
    init_arg => undef,
    default => 0,
);

# helper / cache: maps each (queried) workflow type to the ACL defined for the current user's role
has 'acl_by_wftype' => (
    isa => 'HashRef',
    is => 'rw',
    init_arg => undef,
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
    ##! 1: "start"

    my $columns = [ qw(
        workflow_last_update
        workflow.workflow_id
        workflow_type
        workflow_state
        workflow_proc_state
        workflow_wakeup_at
        pki_realm
    ) ];

    return $self->_search($params, $columns);
};

=head2 search_workflow_instances_count

Searches workflow instances using the given parameters and returns the number
of workflows found.

See L</search_workflow_instances> for available parameters. Note that for
compatibility with I<search_workflow_instances> the following parameters are
accepted but ignored: C<return_attributes>, C<start>, C<limit>,
C<order>, C<reverse>.

=cut
command "search_workflow_instances_count" => {
    pki_realm  => { isa => 'AlphaPunct', },
    id         => { isa => 'ArrayRef', },
    type       => { isa => 'ArrayOrAlphaPunct', coerce => 1, },
    state      => { isa => 'ArrayOrAlphaPunct', coerce => 1, },
    proc_state => { isa => 'AlphaPunct', },
    check_acl  => { isa => 'Bool', default => 0 },
    # these are ignored, but included to be compatible to "search_workflow_instances":
    attribute  => { isa => 'ArrayRef|HashRef', },
    start      => { isa => 'Int', },
    limit      => { isa => 'Int', },
    order      => { isa => 'Str', },
    reverse    => { isa => 'Bool', },
    return_attributes => {isa => 'ArrayRef', },
} => sub {
    my ($self, $params) = @_;

    ##! 1: "start"

    $params->clear_start;
    $params->clear_limit;
    $params->clear_order;
    $params->clear_reverse;

    $self->count_only(1);

    # 'workflow_type' and 'creator' needed to apply regex ACLs later on
    $params->return_attributes([ 'creator' ]);
    my $columns = [ qw( workflow_type ) ];
    my $result = $self->_search($params, $columns);

    return scalar @$result;
};

# Execute search and apply ACL checks
sub _search {
    my ($self, $params, $columns) = @_;

    my %sql = %{ $self->_make_query_params($params, $columns) };

    # run SELECT query
    my $result = CTX('dbi')->select(%sql)->fetchall_arrayref({});

    # ACLs part 3: apply ACL checks of type RegEx by filtering 'creator'
    if ($params->check_acl) {
        my ($acl, $is_regex);

        # check if there's any regex ACL
        my $at_least_one_regex_acl = 0;

        # map: workflow_type => is_regex_acl
        my $acl_by_type = {
            map {
                $acl = $self->acl_by_wftype->{$_};
                # ACL of type regex?
                $is_regex = $acl !~ /^(any|self|others)$/;
                $at_least_one_regex_acl |= $is_regex;
                ( $_ => { acl => $acl, is_regex => $is_regex } )
            }
            keys %{ $self->acl_by_wftype }
        };

        if ($at_least_one_regex_acl) {
            # apply regex checks
            my $type;
            $result = [ grep {
                $type = $_->{workflow_type};
                $acl = $acl_by_type->{$type}->{acl};
                # if it's a regex...
                $acl_by_type->{$type}->{is_regex}
                    ? $_->{creator} =~ qr/$acl/  # ...apply it
                    : 1
            } @$result ];
        }
    }

    return $result;
}

# Create SQL query parameters by processing API command parameters
sub _make_query_params {
    my ($self, $args, $columns) = @_;

    my $re_alpha_string = qr{ \A [ \w \- \. : \s ]* \z }xms;

    my $where = {};
    my $params = {
        where => $where,
        columns => $columns,
    };

    ##! 16: 'Input args ' . Dumper $args

    #
    # ACLs part 1: filter out workflow types with undefined ACLs (= no access)
    #
    my $user;
    if ($args->check_acl) {
        $user = CTX('session')->data->user;
        my $role = CTX('session')->data->has_role ? CTX('session')->data->role : 'Anonymous';

        my @wf_types_to_check = $args->has_type
            ? @{ $args->type } # if specified, only query given workflow types ('type' param is always an ArrayRef)
            : CTX('config')->get_keys([ 'workflow', 'def' ]); # otherwise: query all types

        my $add_creator = 0; # only join workflow_attributes table if neccessary

        for my $type (@wf_types_to_check) {
            my $creator_acl = CTX('config')->get([ 'workflow', 'def', $type, 'acl', $role, 'creator' ]);

            # do not query this workflow type if there's no ACL (i.e. no access) for the current user's role
            next unless $creator_acl;


            # store ACLs:
            # 1. as a cache for the other for-loop below that inserts WHERE clauses
            # 2. to remember ACLs of type "RegEx" where checks have to be done after the SQL query
            $self->acl_by_wftype->{$type} = $creator_acl;

            # add 'creator' column to be able to filter on it using WHERE later on
            $add_creator = 1 if $creator_acl ne 'any'; # any = no restriction: user may see all workflows
        }

        ##! 32: 'ACL check - workflow types and ACLs: ' . join(", ", map { sprintf "%s=%s", $_, $self->acl_by_wftype->{$_} } keys %{ $self->acl_by_wftype })

        # add the "creator" column
        push @{ $args->return_attributes }, 'creator' if $add_creator;

        # we do not add $where->{workflow_type} here, it's done later on in more detail
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
    if ($args->check_acl) {
        my @where_additions = ( \"0 = 1" );
        # WHERE ( 0 = 1 OR ... ) is a trick to make sure that NO rows are
        # returned (instead of ALL rows) if $self->acl_by_wftype is empty and
        # thus no other conditions are added.
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

    # process special API command parameters for non-counting search
    if (not $self->count_only) {
        if ($args->has_limit ) {
            $params->{limit} = $args->limit;
            $params->{offset} = $args->start if $args->has_start;
        }

        # Custom ordering
        my $desc = "-"; # not set or 0 means: DESCENDING, i.e. "-"
        $desc = "" if $args->has_reverse and $args->reverse == 0;
        my $order = $args->has_order ? $args->order : 'workflow_id';
        $params->{order_by} = sprintf "%s%s", $desc, $order;
    }

    ##! 32: 'generated parameters: ' . Dumper $params
    return $params;
}

__PACKAGE__->meta->make_immutable;
