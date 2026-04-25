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

List of enabled key usage bits. Valid values: C<digitalSignature>,
C<nonRepudiation>, C<keyEncipherment>, C<dataEncipherment>, C<keyAgreement>,
C<keyCertSign>, C<cRLSign>, C<encipherOnly>, C<decipherOnly>.

=cut

has bits => (
    is       => 'ro',
    isa      => 'ArrayRef[KeyUsageBit]',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
