package OpenXPKI::Crypt::SubjectAltName::DirName;
use OpenXPKI -class;
use OpenXPKI::Types;

extends 'OpenXPKI::Crypt::SubjectAltName';

=head1 NAME

OpenXPKI::Crypt::SubjectAltName::DirName - SAN entry of type directoryName

=head1 SYNOPSIS

  my $san = OpenXPKI::Crypt::SubjectAltName::DirName->new(
      value => 'CN=Example,DC=example,DC=org',
  );
  # $san->type eq 'dirName'

=head1 ATTRIBUTES

=head2 type

Fixed to C<'dirName'>. Not a constructor argument.

=cut

has '+type' => (
    default  => 'dirName',
    init_arg => undef,
);

=head2 value (ParsedDN, required)

The directory name as a parsed RDN sequence
(C<[ [ [attr, val], ... ], ... ]> as returned by L<OpenXPKI::DN/get_parsed>).
A plain DN string is automatically coerced via L<OpenXPKI::DN>.

=cut

has value => (
    is       => 'ro',
    isa      => 'ParsedDN',
    coerce   => 1,
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
