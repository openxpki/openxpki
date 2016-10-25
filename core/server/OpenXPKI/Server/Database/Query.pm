package OpenXPKI::Server::Database::Query;

use strict;
use warnings;
use utf8;

use Moose;

use OpenXPKI::Debug;
use MooseX::Params::Validate;
use SQL::Abstract::More; # TODO Use SQL::Maker instead of SQL::Abstract::More? (but the former only supports Oracle type LIMITs)

#
# Constructor arguments
#

has 'driver' => (
    is => 'ro',
    does => 'OpenXPKI::Server::Database::DriverRole',
    required => 1,
);

#
# Other attributes
#

has 'sql_str' => (
    is => 'rw',
    isa => 'Str',
);

has 'sql_params' => (
    is => 'rw',
    isa => 'ArrayRef',
    traits  => ['Array'],
    handles => {
        add_sql_params => 'push',
    },
);

has 'sqlam' => ( # SQL query builder
    is => 'rw',
    isa => 'SQL::Abstract::More',
    lazy => 1,
    builder => '_build_sqlam',
);

sub _build_sqlam {
    my $self = shift;
    # TODO Support Oracle 12c LIMIT syntax: OFFSET 4 ROWS FETCH NEXT 4 ROWS ONLY
    # TODO Support LIMIT for other DBs by giving a custom sub to "limit_offset"
    my %attrs = do {
        if ('Oracle' eq $self->driver->dbi_driver) {
            (sql_dialect => 'Oracle');
        }
        else {
            ()
        }
    };
    return SQL::Abstract::More->new(%attrs);
}

#
# Methods
#

# Prefixes the given DB table name with a namespace (if there's not already
# one part of the table name)
sub _add_namespace_to {
    my $self = shift;
    my ($obj_param) = pos_validated_list(\@_,
        { isa => 'Str | ArrayRef[Str]' },
    );
    # no namespace defined
    return $obj_param unless $self->driver->namespace;
    # make sure we always have an ArrayRef
    my $obj_list = ref $obj_param eq 'ARRAY' ? $obj_param : [ $obj_param ];
    # add namespace if there's not already a namespace in the object name
    $obj_list = [ map { m/\./ ? $_ : $self->driver->namespace.'.'.$_ } @$obj_list ];
    # return same type as argument was (ArrayRef or scalar)
    return ref $obj_param eq 'ARRAY' ? $obj_list : $obj_list->[0];
}

# Calls the given SQL::Abstract::More method after converting the parameters.
# Sets $self->sql_str and $self->sql_params
sub _call_sqlam {
    my ($self, $method, $params) = @_;

    # Prefix arguments with dash "-"
    my %sqlam_param = map { '-'.$_ => $params->{$_} } keys %$params;
    ##! 2: "SQL::Abstract::More->$method(" . join(", ", map { sprintf "%s = %s", $_, Data::Dumper->new([$sqlam_param{$_}])->Indent(0)->Terse(1)->Dump } sort keys %sqlam_param) . ")"

    # Call SQL::Abstract::More method and store results
    my ($sql, @bind) = $self->sqlam->$method(%sqlam_param);
    $self->sql_str($sql);
    $self->add_sql_params(@bind); # there might already be bind values from a JOIN
}

sub select {
    my ($self, %params) = validated_hash(\@_,   # MooseX::Params::Validate
        columns   => { isa => 'ArrayRef[Str]' },
        from      => { isa => 'Str | ArrayRef[Str]', optional => 1 },
        from_join => { isa => 'Str', optional => 1 },
        where     => { isa => 'Str | ArrayRef | HashRef', optional => 1 },
        group_by  => { isa => 'Str | ArrayRef', optional => 1 },
        having    => { isa => 'Str | ArrayRef | HashRef', optional => 1, depends => ['group_by'] },
        order_by  => { isa => 'Str | ArrayRef', optional => 1 },
        limit     => { isa => 'Int', optional => 1 },
        offset    => { isa => 'Int', optional => 1 },
    );

    # FIXME order_by: if ArrayRef then check for "asc" and "desc" as they are reserved words (https://metacpan.org/pod/SQL::Abstract::More#select)

    die "You must provide either 'from' or 'from_join'"
        unless ($params{'from'} or $params{'from_join'});

    # Add namespace to table name
    $params{'from'} = $self->_add_namespace_to($params{'from'}) if $params{'from'};

    # Provide nicer syntax for joins than SQL::Abstract::More
    # TODO Test JOIN syntax (especially ON conditions, see https://metacpan.org/pod/SQL::Abstract::More#join)
    if ($params{'from_join'}) {
        die "You cannot specify 'from' and 'from_join' at the same time"
            if $params{'from'};
        my @join_spec = split(/\s+/, $params{'from_join'});
        # Add namespace to table names (= all even indexes in join spec list)
        for (my $i=0; $i<scalar(@join_spec); $i+=2) {
            my @parts = split /\|/, $join_spec[$i];   # "table" / "table|alias"
            $parts[0] = $self->_add_namespace_to($parts[0]);
            $join_spec[$i] = join '|', @parts;
        }
        # Translate JOIN spec into SQL syntax - taken from SQL::Abstract::More->select.
        # (string is converted into the list that SQL::Abstract::More->join expects)
        my $join_info = $self->sqlam->join(@join_spec);
        $params{'from'} = \($join_info->{sql});
        $self->add_sql_params( @{$join_info->{bind}} ) if $join_info;
        delete $params{'from_join'};
    }

    $self->_call_sqlam('select', \%params);
    return $self;
}

sub insert {
    my ($self, %params) = validated_hash(\@_,   # MooseX::Params::Validate
        into     => { isa => 'Str' },
        values   => { isa => 'HashRef' },
    );

    # Add namespace to table name
    $params{'into'} = $self->_add_namespace_to($params{'into'}) if $params{'into'};

    $self->_call_sqlam('insert', \%params);
    return $self;
}

# Binds the parameters to the given statement handle
sub bind_params_to {
    my ($self, $sth) = @_;
    $self->sqlam->bind_params($sth, @{$self->sql_params});
}

1;

=head1 Name

OpenXPKI::Server::Database::Query - Represents an SQL query

=head1 Description

This class encapsulates an SQL query that is executed later on.

Most of the work is delegated to L<SQL::Abstract::More>.

=head1 Attributes

=head2 sql_str

The SQL I<string> that is generated after a query method is called.

=head2 sql_params

An I<ArrayRef> containing all SQL bind parameters after a query method is called.

=head1 Methods

=head2 new

Class method that creates an empty query object.

Named parameters:

=over

=item * B<db_type> - DBI compliant case sensitive driver name (I<Str>, required)

=item * B<db_version> - Database version as returned by C<$dbh-E<gt>get_version(...)> (I<Str>, required)

=item * B<db_namespace> - Schema/namespace that will be added as table prefix in all queries. Could e.g. be used to store multiple OpenXPKI installations in one database (I<Str>)

=back

=head2 select

Builds a SELECT query and stores SQL string and bind parameters internally.

Named parameters:

=over

=item * B<columns> - List of column names (I<ArrayRef[Str]>, required)

=item * B<from> - Table name (or list of) (I<Str | ArrayRef[Str]>, required)

=item * B<from_join> - A B<string> to describe table relations for FROM .. JOIN following the spec in L<SQL::Abstract::More/join> (I<Str>)

    from_join => "certificate  req_key=req_key  csr"

Please note that you cannot specify C<from> and C<from_join> at the same time.

=item * B<where> - WHERE clause following the spec in L<SQL::Abstract/WHERE-CLAUSES> (I<Str | ArrayRef | HashRef>)

=item * B<group_by> - GROUP BY column (or list of) (I<Str | ArrayRef>)

=item * B<having> - HAVING clause following the spec in L<SQL::Abstract/WHERE-CLAUSES> (I<Str | ArrayRef | HashRef>)

=item * B<order_by> - Plain ORDER BY string or list of columns. Each column name can be preceded by a "-" for descending sort (I<Str | ArrayRef>)

=item * B<limit> - (I<Int>)

=item * B<offset> - (I<Int>)

=back

=head2 insert

Builds an INSERT query and stores SQL string and bind parameters internally.

Named parameters:

=over

=item * B<into> - Table name (I<Str>, required)

=item * B<values> - Hash with column name / value pairs. Please note that C<undef> is interpreted as C<NULL> (I<HashRef>, required)

=back

=head2 bind_params_to

Binds the (internally stored) SQL parameters to the given statement handle.

Parameters:

=over

=item * B<$sth> - DBI statement handle (I<DBI::sth>, required)

=back

=cut
