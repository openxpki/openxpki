package OpenXPKI::Crypt::Profile::CSR;
use OpenXPKI -class;
with 'OpenXPKI::Crypt::Profile::Role::Subject';
with 'OpenXPKI::Crypt::Profile::Role::SubjectAltName';

=head1 NAME

OpenXPKI::Crypt::Profile::CSR - Moose-based PKCS#10 CSR profile

=head1 SYNOPSIS

  my $profile = OpenXPKI::Crypt::Profile::CSR->new();
  $profile->set_subject_alt_name([['DNS','www.example.com'], ['IP','192.0.2.1']]);

=head1 DESCRIPTION

Profile object for PKCS#10 CSR generation, passed to
L<OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs10>.
Unlike the CA-facing profile classes, this class has no issuer context and no CTX dependency.

SAN handling (C<subject_alt_name> attribute, L</add_subject_alt_name>,
L</set_subject_alt_name>) is provided by
L<OpenXPKI::Crypt::Profile::Role::SubjectAltName>.

=head1 ATTRIBUTES

=cut

has digest => (
    reader  => 'get_digest',
    isa     => 'Str',
    default => 'sha256',
);

has string_mask => (
    reader  => 'get_string_mask',
    isa     => 'Str',
    default => 'utf8only',
);


=head1 METHODS

###########################################################################
# Config serialisation API for OpenXPKI::Crypto::Backend::OpenSSL::Config

=head2 get_named_extensions

Returns C<('subject_alt_name')> when SANs are present, empty list otherwise.

=cut

sub get_named_extensions {
    my $self = shift;
    return ('subject_alt_name')
        if $self->has_subject_alt_name && scalar @{ $self->subject_alt_name // [] };
    return ();
}

=head2 is_critical_extension($name)

CSR SANs are never marked critical.

=cut

sub is_critical_extension { return '' }

=head2 get_extension($name)

Returns C<[[$type, $value], ...]> for C<subject_alt_name>, empty list otherwise.

Note: C<dirName> SANs are returned with a C<ParsedDN> value (ArrayRef), which
C<__get_extensions> in C<Config.pm> does not handle. DirName SANs in PKCS#10
requests are unsupported.

=cut

sub get_extension {
    my ($self, $name) = @_;
    return [] unless $name eq 'subject_alt_name';
    my $list = $self->subject_alt_name // [];
    return [map { [$_->type, $_->value] } @$list];
}

=head2 get_oid_extensions

Always returns an empty list (no custom OIDs in PKCS#10 profiles).

=cut

sub get_oid_extensions { return () }

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<OpenXPKI::Crypt::Profile::Role::SubjectAltName>,
L<OpenXPKI::Crypt::Profile::Certificate>,
L<OpenXPKI::Crypt::Profile::CRL>,
L<OpenXPKI::Crypto::Backend::OpenSSL::Config>

=cut
