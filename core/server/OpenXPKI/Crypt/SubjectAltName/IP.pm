package OpenXPKI::Crypt::SubjectAltName::IP;
use OpenXPKI -class;
use OpenXPKI::Types;

extends 'OpenXPKI::Crypt::SubjectAltName';

=head1 NAME

OpenXPKI::Crypt::SubjectAltName::IP - SAN entry of type iPAddress

=head1 SYNOPSIS

  my $san = OpenXPKI::Crypt::SubjectAltName::IP->new(value => '192.0.2.1');
  my $san6 = OpenXPKI::Crypt::SubjectAltName::IP->new(value => '2001:db8::1');
  # $san->type eq 'IP'

=head1 ATTRIBUTES

=head2 type

Fixed to C<'IP'>. Not a constructor argument.

=cut

has '+type' => (
    default  => 'IP',
    init_arg => undef,
);

=head2 value (IP, required)

IPv4 or IPv6 address in standard dotted / colon-hex notation.

=cut

has value => (
    is       => 'ro',
    isa      => 'IP',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
