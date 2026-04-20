package OpenXPKI::Crypt::Profile::DTO::AuthorityKeyIdentifier;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::AuthorityKeyIdentifier - DTO for the X.509 authorityKeyIdentifier extension

=head1 ATTRIBUTES

=head2 critical (Bool, required)

Whether the extension is marked critical.

=cut

has critical => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

=head2 keyid (Bool, default 0)

Include the key identifier (keyIdentifier field).

=cut

has keyid => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

=head2 issuer (Bool, default 0)

Include the issuer name and serial (authorityCertIssuer / authorityCertSerialNumber fields).

=cut

has issuer => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

__PACKAGE__->meta->make_immutable;
1;
