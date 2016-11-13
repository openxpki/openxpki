package OpenXPKI::Server::Workflow::Persister::DBI::SequenceId;
use Moose;
use utf8;

use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

has table_name => (
    is => "rw",
    isa => "Str",
);

sub pre_fetch_id {
    my $self = shift;
    return CTX('dbi')->next_id($self->table_name);
}

sub post_fetch_id {
    return;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Persister::DBI::SequenceId

=head1 Description

Implementation for OpenXPKI's DBI persister to fetch ID values from a
sequence (or emulation of a sequence).

=head1 Functions

=head2 pre_fetch_id

Called by the persister implementation during object creation,
before performing a database action.
Returns a unique, increasing id.

=head2 post_fetch_id

Called by the persister implementation during object creation,
after performing a database action.
Returns undef.
