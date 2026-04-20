package OpenXPKI::Crypt::SubjectAltName;
use OpenXPKI -class;
use OpenXPKI::Types;

=head1 NAME

OpenXPKI::Crypt::SubjectAltName - Base class for Subject Alternative Name entries

=head1 DESCRIPTION

Abstract base class for a single Subject Alternative Name (SAN) entry.
Each SAN type has a dedicated subclass with typed C<value> validation:

=over

=item L<OpenXPKI::Crypt::SubjectAltName::DNS>

=item L<OpenXPKI::Crypt::SubjectAltName::Email>

=item L<OpenXPKI::Crypt::SubjectAltName::IP>

=item L<OpenXPKI::Crypt::SubjectAltName::URI>

=item L<OpenXPKI::Crypt::SubjectAltName::DirName>

=item L<OpenXPKI::Crypt::SubjectAltName::RID>

=item L<OpenXPKI::Crypt::SubjectAltName::OtherName>

=back

Subclasses set C<type> to a fixed value and require C<value> to be provided.

=head1 ATTRIBUTES

=head2 type (SANType, required)

The SAN type. One of: C<DNS>, C<email>, C<IP>, C<URI>, C<dirName>, C<RID>, C<otherName>.

=cut

has type => (
    is       => 'ro',
    isa      => 'SANType',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
