package OpenXPKI::Crypt::Profile::DTO::AuthorityInfoAccess;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::AuthorityInfoAccess - DTO for the X.509 authorityInfoAccess extension

=head1 ATTRIBUTES

=head2 critical (Bool, required)

Whether the extension is marked critical.

=cut

has critical => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

=head2 ca_issuers (Maybe[ArrayRef[GeneralNameNoBreak]])

List of caIssuers access URIs (after Template Toolkit processing).

=cut

has ca_issuers => (
    is  => 'ro',
    isa => 'Maybe[ArrayRef[GeneralNameNoBreak]]',
);

=head2 ocsp (Maybe[ArrayRef[GeneralNameNoBreak]])

List of OCSP responder URIs (after Template Toolkit processing).

=cut

has ocsp => (
    is  => 'ro',
    isa => 'Maybe[ArrayRef[GeneralNameNoBreak]]',
);

__PACKAGE__->meta->make_immutable;
1;
