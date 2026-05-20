package OpenXPKI::Crypt::Profile::Role::Subject;
use OpenXPKI -role;


=head2 subject (ParsedDN, rw)

Subject distinguished name as a parsed RDN sequence.

Write access via C<set_subject>, accepts a plain DN string which is coerced
via L<OpenXPKI::DN>.

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

=cut

sub get_subject {
    my $self = shift;
    return '' unless defined $self->subject && scalar @{ $self->subject };
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
