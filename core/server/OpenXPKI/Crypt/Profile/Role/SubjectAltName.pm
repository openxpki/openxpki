package OpenXPKI::Crypt::Profile::Role::SubjectAltName;
use OpenXPKI -role;

use OpenXPKI::Crypt::SubjectAltName::DNS;
use OpenXPKI::Crypt::SubjectAltName::Email;
use OpenXPKI::Crypt::SubjectAltName::IP;
use OpenXPKI::Crypt::SubjectAltName::URI;
use OpenXPKI::Crypt::SubjectAltName::DirName;
use OpenXPKI::Crypt::SubjectAltName::RID;
use OpenXPKI::Crypt::SubjectAltName::OtherName;

my %_SAN_CLASS = (
    DNS       => 'OpenXPKI::Crypt::SubjectAltName::DNS',
    email     => 'OpenXPKI::Crypt::SubjectAltName::Email',
    IP        => 'OpenXPKI::Crypt::SubjectAltName::IP',
    URI       => 'OpenXPKI::Crypt::SubjectAltName::URI',
    dirName   => 'OpenXPKI::Crypt::SubjectAltName::DirName',
    RID       => 'OpenXPKI::Crypt::SubjectAltName::RID',
    otherName => 'OpenXPKI::Crypt::SubjectAltName::OtherName',
);

=head1 NAME

OpenXPKI::Crypt::Profile::Role::SubjectAltName - shared SAN handling for profile classes

=head1 DESCRIPTION

Provides the L</subject_alt_name> attribute and the L</add_subject_alt_name> /
L</set_subject_alt_name> methods for profile classes that need to carry Subject
Alternative Name data (L<OpenXPKI::Crypt::Profile::Certificate> and
L<OpenXPKI::Crypt::Profile::CSR>).

=head1 ATTRIBUTES

=head2 subject_alt_name (Maybe[ArrayRef[OpenXPKI::Crypt::SubjectAltName]], rw)

Subject Alternative Name list. Not loaded from config — set externally
via L</add_subject_alt_name>, L</set_subject_alt_name>, or directly.

=cut

has subject_alt_name => (
    is        => 'rw',
    isa       => 'Maybe[ArrayRef[OpenXPKI::Crypt::SubjectAltName]]',
    predicate => 'has_subject_alt_name',
    init_arg  => undef,
);

=head1 METHODS

=head2 add_subject_alt_name(\@san)

Accepts a single C<[$type, $value]> pair and appends the corresponding
L<OpenXPKI::Crypt::SubjectAltName> object to L</subject_alt_name>.

Throws C<I18N_OPENXPKI_CRYPT_PROFILE_UNKNOWN_SAN_TYPE> for unknown types.

=cut

sub add_subject_alt_name {
    my ($self, $san) = @_;
    my ($type, $value) = @$san;
    my $class = $_SAN_CLASS{$type}
        or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPT_PROFILE_UNKNOWN_SAN_TYPE',
            params  => { TYPE => $type },
        );
    my $obj = $class->new(value => $value);
    my @list = @{ $self->subject_alt_name // [] };
    push @list, $obj;
    $self->subject_alt_name(\@list);
    return $self;
}

=head2 set_subject_alt_name(\@list)

Bulk-setter that accepts an ArrayRef of C<[$type, $value]> pairs.
Replaces any previously set SANs.

=cut

sub set_subject_alt_name {
    my ($self, $list) = @_;
    $self->subject_alt_name(undef);
    for my $entry (@$list) {
        $self->add_subject_alt_name($entry);
    }
    return $self;
}

1;
