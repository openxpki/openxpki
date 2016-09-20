package OpenXPKI::Server::Database::Query;

use strict;
use warnings;
use utf8;

use Moose;

use MooseX::Params::Validate;
use SQL::Abstract::More; # TODO Use SQL::Maker instead of SQL::Abstract::More? (but the former only supports Oracle type LIMITs)

#
# Constructor arguments
#

has 'db_type' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'db_version' => (
    is => 'ro',
    isa => 'Str',
    required => 1
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
        if ('Oracle' eq $self->db_type) {
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

sub select {
    my %valid_param = (
        columns  => { isa => 'ArrayRef[Str]' },
        from     => { isa => 'Str | ArrayRef[Str]' },
        where    => { isa => 'Str | ArrayRef | HashRef', optional => 1 },
        group_by => { isa => 'Str | ArrayRef', optional => 1 },
        having   => { isa => 'Str | ArrayRef | HashRef', optional => 1, depends => ['group_by'] },
        order_by => { isa => 'Str | ArrayRef', optional => 1 },
        limit    => { isa => 'Int', optional => 1 },
        offset   => { isa => 'Int', optional => 1 },
    );
    my ($self, %params) = validated_hash(\@_, %valid_param); # MooseX::Params::Validate
    my %sqlam_param = map { '-'.$_ => $params{$_} } keys %params;

    # FIXME order_by: if ArrayRef then check for "asc" and "desc" as they are reserved words (https://metacpan.org/pod/SQL::Abstract::More#select)

    my ($sql, @bind) = $self->sqlam->select(%sqlam_param);
    $self->sql_str($sql);
    $self->sql_params(\@bind);
    return $self;
}

sub insert {
    my %valid_param = (
        into     => { isa => 'Str' },
        values   => { isa => 'HashRef' },
    );
    my ($self, %params) = validated_hash(\@_, %valid_param); # MooseX::Params::Validate
    my %sqlam_param = map { '-'.$_ => $params{$_} } keys %params;

    my ($sql, @bind) = $self->sqlam->insert(%sqlam_param);
    $self->sql_str($sql);
    $self->sql_params(\@bind);
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

=back

=head2 select

Builds a SELECT query and stores SQL string and bind parameters internally.

Named parameters:

=over

=item * B<columns> - List of column names (I<ArrayRef[Str]>, required)

=item * B<from> - Table name (or list of) (I<Str | ArrayRef[Str]>, required)

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
