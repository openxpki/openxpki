package OpenXPKI::Crypt::Profile::Role::Subject;
use OpenXPKI -role;


=head2 subject (ParsedDN, rw)

Subject distinguished name as a parsed RDN sequence.
Accepts a plain DN string which is coerced via L<OpenXPKI::DN>.

=cut

has subject => (
    is       => 'rw',
    isa      => 'ParsedDN',
    coerce   => 1,
    writer   => 'set_subject',
    init_arg => undef,
);

=head2 get_subject

Returns the subject as an RFC 2253 DN string.
Throws an exception when no subject has been set.

Use C<< $profile->subject >> directly to access the parsed C<ParsedDN> arrayref.

=cut

sub get_subject {
    my $self = shift;
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_CRYPT_PROFILE_GET_SUBJECT_NOT_PRESENT',
    ) unless defined $self->subject && scalar @{ $self->subject };
    # Reconstruct an RFC 2253 string from the stored ParsedDN so that callers
    # (e.g. OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_cert) can pass
    # the result directly to OpenXPKI::DN->new() or use it in regex checks.
    my $dn_obj = bless { PARSED => $self->subject }, 'OpenXPKI::DN';
    $dn_obj->__build_rdns();
    return $dn_obj->get_rfc_2253_dn();
}

=head2 get_parsed_dn (ParsedDN)

Returns the subject as ParsedDN.

=cut

sub get_parsed_dn {
    return shift->subject();
}

1;
