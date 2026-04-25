package OpenXPKI::Crypt::Profile::DTO::Policy;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::Policy - DTO for a single certificate policy entry

=head1 DESCRIPTION

Represents one entry in the X.509 certificatePolicies extension.
Used inside L<OpenXPKI::Crypt::Profile::DTO::PolicyIdentifier>.

=head1 ATTRIBUTES

=head2 oid (Str, required)

The policy OID in dotted-decimal notation (e.g. C<1.2.840.113549.1.9.14>).

=cut

has oid => (
    is       => 'ro',
    isa      => 'OID',
    required => 1,
);

=head2 cps (Maybe[ArrayRef[Str]])

Optional list of CPS (Certification Practice Statement) URIs.

=cut

has cps => (
    is  => 'ro',
    isa => 'Maybe[ArrayRef[URI]]',
);

=head2 user_notice (Maybe[ArrayRef[GeneralName]])

Optional list of user notice texts.

=cut

has user_notice => (
    is  => 'ro',
    isa => 'Maybe[ArrayRef[GeneralName]]',
);

__PACKAGE__->meta->make_immutable;
1;
