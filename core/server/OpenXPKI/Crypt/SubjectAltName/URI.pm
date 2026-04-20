package OpenXPKI::Crypt::SubjectAltName::URI;
use OpenXPKI -class;
use OpenXPKI::Types;

extends 'OpenXPKI::Crypt::SubjectAltName';

=head1 NAME

OpenXPKI::Crypt::SubjectAltName::URI - SAN entry of type uniformResourceIdentifier

=head1 SYNOPSIS

  my $san = OpenXPKI::Crypt::SubjectAltName::URI->new(
      value => 'https://example.com',
  );
  # $san->type eq 'URI'

=head1 ATTRIBUTES

=head2 type

Fixed to C<'URI'>. Not a constructor argument.

=cut

has '+type' => (
    default  => 'URI',
    init_arg => undef,
);

=head2 value (URI, required)

The URI string. Must start with a scheme followed by C<://>.

=cut

has value => (
    is       => 'ro',
    isa      => 'URI',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
