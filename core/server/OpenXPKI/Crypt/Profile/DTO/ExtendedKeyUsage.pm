package OpenXPKI::Crypt::Profile::DTO::ExtendedKeyUsage;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::ExtendedKeyUsage - DTO for the X.509 extendedKeyUsage extension

=head1 ATTRIBUTES

=head2 critical (Bool, required)

Whether the extension is marked critical.

=cut

has critical => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

=head2 usages (ArrayRef[Str], required)

List of enabled extended key usages. Values are either named usages
(C<client_auth>, C<server_auth>, C<email_protection>, C<code_signing>,
C<time_stamping>, C<ocsp_signing>) or numeric OID strings.

=cut

has usages => (
    is       => 'ro',
    isa      => 'ArrayRef[Str]',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
