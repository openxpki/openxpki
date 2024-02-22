package OpenXPKI::Server::Database::QueryBuilder;
use Moose;
use namespace::autoclean;

=head1 Name

OpenXPKI::Server::Database::QueryBuilder - Programmatic interface to SQL queries

=cut

# CPAN modules
use SQL::Abstract::More; # TODO Use SQL::Maker instead of SQL::Abstract::More? (but the former only supports Oracle type LIMITs)
use Type::Params qw( signature_for );

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Database::Query;

# should be done after imports to safely disable warnings in Perl < 5.36
use experimental 'signatures';

################################################################################
# Attributes
#

# Constructor arguments

has 'driver' => (
    is => 'ro',
    does => 'OpenXPKI::Server::Database::Role::Driver',
    required => 1,
);

has 'sqlam' => ( # SQL query builder
    is => 'ro',
    isa => 'SQL::Abstract::More',
    required => 1,
);

has 'namespace' => ( # database namespace (i.e. schema) to prepend to tables
    is => 'ro',
    isa => 'Str',
);

################################################################################
# Methods
#

# Prefixes the given DB table name with a namespace (if there's not already
# one part of the table name)
signature_for _add_namespace_to => (
    method => 1,
    positional => [ 'Str' ],
);
sub _add_namespace_to ($self, $name) {
    # no namespace defined
    return $name unless $self->namespace;
    # add namespace if there's not already a namespace in the object name
    return $name =~ m/\./ ? $name : $self->namespace.'.'.$name;
}

# Calls the given SQL::Abstract::More method after converting the parameters.
# Sets $self->sql_str and $self->sql_params
signature_for _make_query => (
    method => 1,
    positional => [
        'Str',
        'HashRef',
        'Optional[OpenXPKI::Server::Database::Query]' => {
            default => sub { OpenXPKI::Server::Database::Query->new },
        },
    ]
);
sub _make_query ($self, $method, $args, $query_obj) {
    # Workaround for passing literal WHERE queries.
    # Required because:
    #  - SQL::Abstract::More expects a Scalar while (the later invoked)
    #  - SQL::Abstract       expects a ScalarRef.
    # So we expect a ScalarRef and wrap it for SQL::Abstract::More.
    my $is_scalar_ref = $args->{where} && ref $args->{where} eq 'SCALAR';
    if ($is_scalar_ref) {
        $args->{where} = { -and => [ $args->{where} ] }; # wrap ScalarRef in innocuous query
    }

    # Prefix arguments with dash "-"
    my %sqlam_args = map { '-'.$_ => $args->{$_} } keys $args->%*;

    ##! 4: "SQL::Abstract::More->$method(" . join(", ", map { sprintf "%s = %s", $_, Data::Dumper->new([$sqlam_args{$_}])->Indent(0)->Terse(1)->Dump } sort keys %sqlam_args) . ")"

    # Call SQL::Abstract::More method and store results
    my ($sql, @bind) = $self->sqlam->$method(%sqlam_args);

    # Custom SQL replacements to support non-standard SQL (e.g. FROM_UNIXTIME)
    $sql = $self->driver->do_sql_replacements($sql);

    $query_obj->string($sql);
    $query_obj->add_params(@bind); # there might already be bind values from a JOIN

    return $query_obj;
}

signature_for select => (
    method => 1,
    named => [
        columns   => 'ArrayRef[Str]',
        from      => 'Optional[ Str | ArrayRef[Str] ]',
        from_join => 'Optional[ Str ]',
        where     => 'Optional[ ScalarRef | ArrayRef | HashRef ]',
        group_by  => 'Optional[ Str | ArrayRef ]',
        having    => 'Optional[ Str | ArrayRef | HashRef ]',
        order_by  => 'Optional[ Str | ArrayRef ]',
        limit     => 'Optional[ Int ]',
        offset    => 'Optional[ Int ]',
        distinct  => 'Optional[ Bool ]',
    ],
    bless => !!0, # return a HashRef instead of an Object
);
sub select ($self, $arg) {
    # FIXME order_by: if ArrayRef then check for "asc" and "desc" as they are reserved words (https://metacpan.org/pod/SQL::Abstract::More#select)

    OpenXPKI::Exception->throw(message => "There must be at least one column name in 'columns'")
        unless scalar @{$arg->{columns}} > 0;

    OpenXPKI::Exception->throw(message => "Either 'from' or 'from_join' must be specified")
        unless ($arg->{from} or $arg->{from_join});

    # Add namespace to table name
    $arg->{from} = $self->_add_namespace_to($arg->{from}) if $arg->{from};

    if ($arg->{distinct}) {
        delete $arg->{distinct};
        $arg->{columns} = [ -distinct => @{$arg->{columns}} ];
    }

    # Provide nicer syntax for joins than SQL::Abstract::More
    # TODO Test JOIN syntax (especially ON conditions, see https://metacpan.org/pod/SQL::Abstract::More#join)
    my $query;
    if ($arg->{from_join}) {
        die "You cannot specify 'from' and 'from_join' at the same time"
            if $arg->{from};
        my @join_spec = split(/\s+/, $arg->{from_join});
        delete $arg->{from_join};
        # Add namespace to table names (= all even indexes in join spec list)
        for (my $i=0; $i<scalar(@join_spec); $i+=2) {
            my @parts = split /\|/, $join_spec[$i];   # "table" / "table|alias"
            $parts[0] = $self->_add_namespace_to($parts[0]);
            $join_spec[$i] = join '|', @parts;
        }
        # Translate JOIN spec into SQL syntax - taken from SQL::Abstract::More->select.
        # (string is converted into the list that SQL::Abstract::More->join expects)
        my $join_info = $self->sqlam->join(@join_spec);
        $arg->{from} = \($join_info->{sql});

        if ($join_info) {
            $query = OpenXPKI::Server::Database::Query->new;
            $query->add_params( @{$join_info->{bind}} );
        }
    }

    return $self->_make_query('select' => $arg, $query // ());
}

signature_for subselect => (
    method => 1,
    positional => [ 'Str', 'HashRef' ],
);
sub subselect ($self, $operator, $query) {
    my $subquery = $self->select(%$query);
    my $subquery_and_op = sprintf "%s (%s)", $operator, $subquery->string;

    return \[ $subquery_and_op => @{ $subquery->params }]
}

signature_for insert => (
    method => 1,
    named => [
        into => 'Str',
        values => 'HashRef',
    ],
    bless => !!0, # return a HashRef instead of an Object
);
sub insert ($self, $arg) {
    # Add namespace to table name
    $arg->{into} = $self->_add_namespace_to($arg->{into});

    return $self->_make_query('insert' => $arg);
}

signature_for update => (
    method => 1,
    named => [
        table => 'Str',
        set   => 'HashRef',
        where => 'ScalarRef | ArrayRef | HashRef', # require WHERE clause to prevent accidential updates on all rows
    ],
    bless => !!0, # return a HashRef instead of an Object
);
sub update ($self, $arg) {
    # Add namespace to table name
    $arg->{table} = $self->_add_namespace_to($arg->{table});

    return $self->_make_query('update' => $arg);
}

signature_for delete => (
    method => 1,
    named => [
        from  => 'Str',
        where => 'Optional[ ScalarRef | ArrayRef | HashRef ]',
        all   => 'Optional[ Bool ]',
    ],
    bless => !!0, # return a HashRef instead of an Object
);
sub delete ($self, $arg) {
    OpenXPKI::Exception->throw(message => "Either 'where' or 'all' must be specified")
        unless ($arg->{where} or $arg->{all});

    OpenXPKI::Exception->throw(message => "Empty parameter 'where' not allowed, use 'all' to enforce deletion of all rows")
        if ($arg->{where} and (
            ( ref $arg->{where} eq "ARRAY" and not scalar @{$arg->{where}} )
            or
            ( ref $arg->{where} eq "HASH" and not scalar keys %{$arg->{where}} )
        ));

    # Add namespace to table name
    $arg->{from} = $self->_add_namespace_to($arg->{from});

    # Delete all rows
    if ($arg->{all}) {
        $arg->{where} = {};
        delete $arg->{all};
    }

    return $self->_make_query('delete' => $arg);
}

__PACKAGE__->meta->make_immutable;

=head1 Description

This class provides methods to create DBMS specific SQL queries that can be
executed later on.

It delegates most of the work to L<SQL::Abstract::More> but offers a slightly
modified and stripped down interface (customized for OpenXPKI).

=head1 Attributes

=head2 Constructor parameters

=over

=item * B<sqlam> - SQL query builder (an instance of L<SQL::Abstract::More>)

=item * B<namespace> - namespace (i.e. schema) to prepend to table names (I<Str>, optional)

=back

=head1 Methods

=head2 new

Constructor.

Named parameters: see L<attributes section above|/"Constructor parameters">.



=head2 select

Builds a SELECT query and returns a L<OpenXPKI::Server::Database::Query> object
which contains SQL string and bind parameters.

The method parameters are documented in L<OpenXPKI::Server::Database/select>.



=head2 subselect

Builds a subselect to be used within another query and returns a reference to an I<ArrayRef>.

This will take something like this:

    CTX('dbi')->subselect('IN' => {
        from => 'nature',
        columns => [ 'id', 'fruit' ],
        where => { type => 'forbidden' }
    })

and turn it into:

    \[ "IN ($query)" => @bind ]

The method parameters are documented in L<OpenXPKI::Server::Database/subselect>.



=head2 insert

Builds an INSERT query and returns a L<OpenXPKI::Server::Database::Query> object
which contains SQL string and bind parameters.

Named parameters:

=over

=item * B<into> - Table name (I<Str>, required)

=item * B<values> - Hash with column name / value pairs. Please note that C<undef> is interpreted as C<NULL> (I<HashRef>, required)

=back



=head2 update

Builds an UPDATE query and returns a L<OpenXPKI::Server::Database::Query> object
which contains SQL string and bind parameters.

A WHERE clause is required to prevent accidential updates of all rows in a table.

The method parameters are documented in L<OpenXPKI::Server::Database/update>.



=head2 delete

Builds a DELETE query and returns an L<OpenXPKI::Server::Database::Query> object
which contains SQL string and bind parameters.

To prevent accidential deletion of all rows of a table you must specify
parameter C<all> if you want to do that:

    $dbi->delete(
        from => "mytab",
        all => 1,
    );

The method parameters are documented in L<OpenXPKI::Server::Database/delete>.

=cut
