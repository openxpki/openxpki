package OpenXPKI::Crypt::SubjectAltName::Email;
use OpenXPKI -class;
use OpenXPKI::Types;

extends 'OpenXPKI::Crypt::SubjectAltName';

=head1 NAME

OpenXPKI::Crypt::SubjectAltName::Email - SAN entry of type rfc822Name

=head1 SYNOPSIS

  my $san = OpenXPKI::Crypt::SubjectAltName::Email->new(
      value => 'user@example.com',
  );
  # $san->type eq 'email'

=head1 ATTRIBUTES

=head2 type

Fixed to C<'email'>. Not a constructor argument.

=cut

has '+type' => (
    default  => 'email',
    init_arg => undef,
);

=head2 value (Email, required)

The RFC 822 email address.

=cut

has value => (
    is       => 'ro',
    isa      => 'Email',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
