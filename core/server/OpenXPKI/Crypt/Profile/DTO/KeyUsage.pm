package OpenXPKI::Crypt::Profile::DTO::KeyUsage;
use OpenXPKI -class;
use OpenXPKI::Types;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::KeyUsage - DTO for the X.509 keyUsage extension

=head1 ATTRIBUTES

=head2 critical (Bool, required)

Whether the extension is marked critical.

=cut

has critical => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

=head2 bits (ArrayRef[KeyUsageBit], required)

List of enabled key usage bits. Valid values: C<digital_signature>,
C<non_repudiation>, C<key_encipherment>, C<data_encipherment>, C<key_agreement>,
C<key_cert_sign>, C<crl_sign>, C<encipher_only>, C<decipher_only>.

=cut

has bits => (
    is       => 'ro',
    isa      => 'ArrayRef[KeyUsageBit]',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
