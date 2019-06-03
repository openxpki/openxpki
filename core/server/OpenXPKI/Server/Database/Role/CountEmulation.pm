package OpenXPKI::Server::Database::Role::CountEmulation;
use Moose::Role;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Role::CountEmulation - Moose role for database
drivers to emulate row count with a subselect

=cut

sub count_rows {

    my ($self, $dbi, $query) = @_;

    $query->string(sprintf "SELECT COUNT(*) as amount FROM (%s) as tmp", $query->string);

    my $sth = $dbi->run($query);
    return $sth->fetchrow_hashref->{amount};

}

1;

__END__;

=head1 Description

This is the default implementation to count the number of rows in a select
by using SELECT COUNT(*) from (...) as tmp

It might be overriden if the specifica RDBMS requires a different syntax
(e.g. Oracle) or there is a builtin method.
