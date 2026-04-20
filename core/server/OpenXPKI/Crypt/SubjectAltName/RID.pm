package OpenXPKI::Crypt::SubjectAltName::RID;
use OpenXPKI -class;
use OpenXPKI::Types;

extends 'OpenXPKI::Crypt::SubjectAltName';

=head1 NAME

OpenXPKI::Crypt::SubjectAltName::RID - SAN entry of type registeredID

=head1 SYNOPSIS

  my $san = OpenXPKI::Crypt::SubjectAltName::RID->new(
      value => '1.2.840.113549.1.9.14',
  );
  # $san->type eq 'RID'

=head1 ATTRIBUTES

=head2 type

Fixed to C<'RID'>. Not a constructor argument.

=cut

has '+type' => (
    default  => 'RID',
    init_arg => undef,
);

=head2 value (OID, required)

The registered OID in dotted-decimal notation.

=cut

has value => (
    is       => 'ro',
    isa      => 'OID',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
