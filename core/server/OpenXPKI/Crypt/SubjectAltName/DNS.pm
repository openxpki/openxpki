package OpenXPKI::Crypt::SubjectAltName::DNS;
use OpenXPKI -class;
use OpenXPKI::Types;

extends 'OpenXPKI::Crypt::SubjectAltName';

=head1 NAME

OpenXPKI::Crypt::SubjectAltName::DNS - SAN entry of type dNSName

=head1 SYNOPSIS

  my $san = OpenXPKI::Crypt::SubjectAltName::DNS->new(
      value => 'example.com',
  );
  # $san->type eq 'DNS'

=head1 ATTRIBUTES

=head2 type

Fixed to C<'DNS'>. Not a constructor argument.

=cut

has '+type' => (
    default  => 'DNS',
    init_arg => undef,
);

=head2 value (Hostname, required)

The DNS hostname. A leading wildcard (C<*>) is permitted.

=cut

has value => (
    is       => 'ro',
    isa      => 'Hostname',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
