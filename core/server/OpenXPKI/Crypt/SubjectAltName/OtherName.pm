package OpenXPKI::Crypt::SubjectAltName::OtherName;
use OpenXPKI -class;

extends 'OpenXPKI::Crypt::SubjectAltName';

=head1 NAME

OpenXPKI::Crypt::SubjectAltName::OtherName - SAN entry of type otherName

=head1 SYNOPSIS

  my $san = OpenXPKI::Crypt::SubjectAltName::OtherName->new(
      oid => '1.3.6.1.4.1.311.20.2.3',
      value   => 'user@domain'
  );
  # $san->type eq 'otherName'

=head1 ATTRIBUTES

=head2 type

Fixed to C<'otherName'>. Not a constructor argument.

=cut

has '+type' => (
    default  => 'otherName',
    init_arg => undef,
);


=head2 oid (Str, required)

The OID describing the type in dotted-decimal notation.

=cut

has oid => (
    is       => 'ro',
    isa      => 'OID',
    required => 1,
);

=head2 value (AlphaPunct, required)

The value of the extension, added to the certificate as is, must be a valid
ASN.1 definition.

=cut

# TODO: might be useful to use CustomOID for the value

has value => (
    is       => 'ro',
    isa      => 'AlphaPunct',
    required => 1,
);

__PACKAGE__->meta->make_immutable;

1;
