package OpenXPKI::Server::Database::Query;
use Moose;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Query - Container for SQL query string and bind parameters

=cut

use OpenXPKI::Debug;

################################################################################
# Attributes
#

# Constructor arguments

has 'string' => (
    is => 'rw',
    isa => 'Str',
);

has 'params' => (
    is => 'rw',
    isa => 'ArrayRef',
    traits  => ['Array'],
    handles => {
        add_params => 'push',
    },
);

sub is_ready {
    my $self = shift;
    return length($self->string) ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

=head1 Description

This class is very simple and only used to pass around the SQL query string and
bind parameters.

=head1 Attributes

=head2 Constructor parameters

=over

=item * B<string> - SQL query (I<Str>)

=item * B<params> - SQL bind parameters (I<ArrayRef>)

=back

=head1 Methods

=head2 new

Constructor.

Named parameters: see L<attributes section above|/"Constructor parameters">.

=cut
