package OpenXPKI::Server::NICE::Role::RevokeCertificate;

use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Moose::Role;

=head1 NAME

OpenXPKI::Server::NICE::Role::RevokeCertificate

=head2 Instance Parameters

=head3 use_revocation_id

Boolean, activate the revocation_id feature. B<Deprecated>

=cut

has use_revocation_id => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

=head3 no_pending_state

Boolean, if set to true the certificate status is directly set to
'REVOKED' instead of 'CRL_ISSUANCE_PENDING'. Note that this disables
the option to rebuild a CRL when new revocations are due based on the
certificate status.

=cut

has no_pending_state => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);


=head2 Methods

=head3 revokeCertificate

Set the certificate status and revocation details to mark a certificate
as revoked. Identifier is mandatory, others are optional, times must be
given as epoch. Defaults are given in brackets.

Returns undef if the certificate was NOT found revoked after database
update. If use_revocation_id is set, returns a hash with revocation_id
set, otherwise returns a literal 1.

=over

=item cert_identifier

=item reason code (unspecified)

=item revocation time (now)

=item invalidity time (not set)

=item hold instruction code (not set)

=back

=cut

sub revokeCertificate {

    my $self = shift;
    my $cert_identifier = shift;
    my $reason_code = shift || 'unspecified';
    my $revocation_time = shift || time();
    my $invalidity_time = shift || undef;
    my $hold_instruction_code = shift || undef;

    ##! 1: 'Start revocation: ' . $cert_identifier

    my $pki_realm = CTX('api2')->get_pki_realm();

    my $update = {
        reason_code => $reason_code,
        revocation_time => $revocation_time,
        invalidity_time => $invalidity_time,
        hold_instruction_code => $hold_instruction_code || undef,
        status => ($self->no_pending_state() ? 'REVOKED' : 'CRL_ISSUANCE_PENDING'),
    };
    my $where = {
        identifier => $cert_identifier,
        pki_realm => $pki_realm,
        status => 'ISSUED',
    };

    my @cols = ('status');
    if ($self->use_revocation_id()) {
        ##! 32: 'using revocation id'
        $update->{revocation_id} = [ '(SELECT coalesce(max(revocation_id)+1, 1) FROM certificate) '];
        $where->{revocation_id} = undef;
        push @cols, 'revocation_id';
    }

    CTX('log')->application()->debug("revoke certificate $cert_identifier");

    ##! 64: $where
    ##! 64: $update
    CTX('dbi')->update(
        table => 'certificate',
        set => $update,
        where => $where,
    );

    ##! 16: 'Checking revocation status'
    my $cert = CTX('dbi')->select_one(
        from => 'certificate',
        columns => \@cols,
        where => { identifier => $cert_identifier },
    );

    if ($cert->{status} !~ m{REVOKED|CRL_ISSUANCE_PENDING}) {
        ##! 16: 'Revocation failed - status is ' . $cert->{status}
        return undef;
    }

    ##! 32: $cert
    return $self->use_revocation_id() ? { revocation_id => $cert->{revocation_id} } : 1;

}

=head3 checkForRevocation

Check if a certificate is marked revoked.

Returns 0 if the certificate is not revoked.

Returns the revocation_id if this feature is active.
Otherwise returns a literal '1'.

=over

=item cert_identifier

=back

=cut

sub checkForRevocation {

    my $self = shift;
    my $cert_identifier  = shift;

    # As the local crl issuance process will set the state in the certificate
    # table directly, we get the certificate status from the local table

    my @cols = ('status');
    if ($self->use_revocation_id()) {
        push @cols, 'revocation_id';
    }

    ##! 16: 'Checking revocation status'
    my $cert = CTX('dbi')->select_one(
        from => 'certificate',
        columns => \@cols,
        where => { identifier => $cert_identifier },
    );

    return undef unless($cert);

    CTX('log')->application()->debug("Check for revocation of $cert_identifier, result: " . $cert->{status});

    ##! 32: 'certificate status ' . $cert->{status}
    return ($cert->{status} eq 'REVOKED') ? ($cert->{revocation_id} || 1) : 0;

}

1;