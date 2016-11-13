package OpenXPKI::Server::Database::Role::MergeEmulation;
use Moose::Role;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Role::MergeEmulation - Moose role for database
drivers to indicate that the DBMS does not provide native support for a MERGE
query

=cut

use MooseX::Params::Validate;

################################################################################
# Required in drivers classes that consume this role
#


################################################################################
# Methods
#

# SQL MERGE emulation
sub merge {
    my ($self, $dbi, @param_list) = @_;
    my (undef, %params) = validated_hash([$self, @param_list],   # MooseX::Params::Validate
        into     => { isa => 'Str' },
        set      => { isa => 'HashRef' },
        set_once => { isa => 'HashRef', optional => 1, default => {} },
        # The WHERE specification contains the primary key columns.
        # In case of an INSERT these will be used as normal values. Therefore
        # we only allow scalars as hash values (which are translated to AND
        # connected "equals" conditions by SQL::Abstract::More).
        where    => { isa => 'HashRef[Value]' },
    );

    my $sth = $dbi->select(
        from => $params{'into'},
        columns => [ keys %{ $params{'where'} } ],
        where => $params{'where'},
    );
    # UPDATE if data exists
    if ($sth->fetchrow_arrayref) {
        return $dbi->update(
            table => $params{'into'},
            set   => $params{'set'},
            where => $params{'where'},
        );
    }
    # INSERT otherwise
    else {
        return $dbi->insert(
            into   => $params{'into'},
            values => {
                %{ $params{'set'} },
                %{ $params{'set_once'} },
                %{ $params{'where'} },
            },
        );
    }
}

1;

=head1 Description

This role emulates an SQL MERGE (you could also call it REPLACE) query through
SELECT + INSERT/UPDATE.

After a SELECT to check for row existance an INSERT or UPDATE query is built
and an L<OpenXPKI::Server::Database::Query> object returned.

=head1 Required methods in the consuming driver class

None.

=cut
