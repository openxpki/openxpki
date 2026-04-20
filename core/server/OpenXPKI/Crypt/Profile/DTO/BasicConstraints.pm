package OpenXPKI::Crypt::Profile::DTO::BasicConstraints;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::BasicConstraints - DTO for the X.509 basicConstraints extension

=head1 ATTRIBUTES

=head2 critical (Bool, required)

Whether the extension is marked critical.

=cut

has critical => (
    is       => 'ro',
    isa      => 'Bool',
    default => 1,
);

=head2 ca (Bool, default 0)

Whether the subject is a CA (cA flag in basicConstraints).

=cut

has ca => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

=head2 path_length (Maybe[Int])

Maximum CA path length (pathLenConstraint). Only meaningful when C<ca> is true.

=cut

has path_length => (
    is  => 'ro',
    isa => 'Maybe[Int]',
);

__PACKAGE__->meta->make_immutable;
1;
