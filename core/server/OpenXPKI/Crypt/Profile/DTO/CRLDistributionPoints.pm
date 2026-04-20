package OpenXPKI::Crypt::Profile::DTO::CRLDistributionPoints;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::CRLDistributionPoints - DTO for the X.509 cRLDistributionPoints extension

=head1 ATTRIBUTES

=head2 critical (Bool, required)

Whether the extension is marked critical.

=cut

has critical => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

=head2 uris (ArrayRef[GeneralNameNoBreak], required)

List of CRL distribution point URIs (after Template Toolkit processing).

=cut

has uris => (
    is       => 'ro',
    isa      => 'ArrayRef[GeneralNameNoBreak]',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
