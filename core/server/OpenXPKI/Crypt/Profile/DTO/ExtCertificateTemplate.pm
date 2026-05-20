package OpenXPKI::Crypt::Profile::DTO::ExtCertificateTemplate;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Crypt::Profile::DTO::ExtCertificateTemplate - DTO for the Microsoft
CertificateTemplate extension (OID 1.3.6.1.4.1.311.21.7)

=head1 ATTRIBUTES

=head2 template_id (Str, required)

OID of the certificate template (dotted decimal notation).

=cut

has template_id => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 major_version (Maybe[Int])

Major version of the certificate template, if present.

=cut

has major_version => (
    is  => 'ro',
    isa => 'Maybe[Int]',
);

=head2 minor_version (Maybe[Int])

Minor version of the certificate template, if present.

=cut

has minor_version => (
    is  => 'ro',
    isa => 'Maybe[Int]',
);

__PACKAGE__->meta->make_immutable;
1;
