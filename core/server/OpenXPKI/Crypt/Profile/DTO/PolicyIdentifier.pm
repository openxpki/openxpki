package OpenXPKI::Crypt::Profile::DTO::PolicyIdentifier;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::PolicyIdentifier - DTO for the X.509 certificatePolicies extension

=head1 ATTRIBUTES

=head2 critical (Bool, required)

Whether the extension is marked critical.

=cut

has critical => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

=head2 policies (ArrayRef[OpenXPKI::Crypt::Profile::DTO::Policy], required)

List of policy entries. Each entry is an
L<OpenXPKI::Crypt::Profile::DTO::Policy> object.

=cut

has policies => (
    is       => 'ro',
    isa      => 'ArrayRef[OpenXPKI::Crypt::Profile::DTO::Policy]',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
