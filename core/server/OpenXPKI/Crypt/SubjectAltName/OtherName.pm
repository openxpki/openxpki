package OpenXPKI::Crypt::SubjectAltName::OtherName;
use OpenXPKI -class;

extends 'OpenXPKI::Crypt::SubjectAltName';

=head1 NAME

OpenXPKI::Crypt::SubjectAltName::OtherName - SAN entry of type otherName

=head1 SYNOPSIS

  my $san = OpenXPKI::Crypt::SubjectAltName::OtherName->new(
      oid   => '1.3.6.1.4.1.311.20.2.3',
      value => 'user@domain',
  );
  # or shorthand: value => '<oid>;<value>'
  my $san = OpenXPKI::Crypt::SubjectAltName::OtherName->new(
      value => '1.3.6.1.4.1.311.20.2.3;user@domain',
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

=head2 value (GeneralName, required)

The value of the extension, added to the certificate as is, must be a valid
ASN.1 definition.

=cut

has value => (
    is       => 'ro',
    isa      => 'GeneralName',
    required => 1,
);

around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;
    if (exists $args{value} && !exists $args{oid} && $args{value} =~ /^([^;]+);(.+)$/) {
        $args{oid}   = $1;
        $args{value} = $2;
    }
    return $class->$orig(%args);
};

__PACKAGE__->meta->make_immutable;

1;
