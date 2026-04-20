package OpenXPKI::Crypt::Profile::DTO::IssuerAltName;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::IssuerAltName - DTO for the X.509 issuerAltName extension

=head1 DESCRIPTION

When configured, the issuerAltName is always copied from the issuing CA
certificate (C<copy> semantics). The DTO therefore only carries the
C<critical> flag.

=head1 ATTRIBUTES

=head2 critical (Bool, required)

Whether the extension is marked critical.

=cut

has critical => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
