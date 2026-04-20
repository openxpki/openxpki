package OpenXPKI::Crypt::Profile::DTO::SubjectKeyIdentifier;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::SubjectKeyIdentifier - DTO for the X.509 subjectKeyIdentifier extension

=head1 DESCRIPTION

When this extension is configured the value is always computed as the SHA-1
hash of the subject public key (C<hash> method). The DTO therefore only
carries the C<critical> flag.

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
