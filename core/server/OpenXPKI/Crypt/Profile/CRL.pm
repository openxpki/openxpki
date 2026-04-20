package OpenXPKI::Crypt::Profile::CRL;
use OpenXPKI -class;
use OpenXPKI::Types;

extends 'OpenXPKI::Crypt::Profile';

# Core modules
use DateTime;

# Project modules
use OpenXPKI::DateTime;
use OpenXPKI::Server::Context qw( CTX );

=head1 NAME

OpenXPKI::Crypt::Profile::CRL - Moose-based CRL profile

=head1 SYNOPSIS

  my $profile = OpenXPKI::Crypt::Profile::CRL->new(
      issuer_alias => 'alpha-signer-1',
  );

  my $days  = $profile->get_nextupdate_in_days;
  my $hours = $profile->get_nextupdate_in_hours;

=head1 DESCRIPTION

Moose-based CRL profile. Extends L<OpenXPKI::Crypt::Profile> with CRL-specific
validity and keep_expired settings.

Profile name resolution:

=over

=item 1. If C<profile_name> is given explicitly it is used as-is.

=item 2. Otherwise the config is checked for C<crl.E<lt>issuer_aliasE<gt>>.

=item 3. Falls back to C<crl.default>.

=back

=head1 ATTRIBUTES

=head2 profile_name (Maybe[Str], optional)

Explicit profile name inside the C<crl> config namespace.

=cut

has profile_name => (
    is  => 'ro',
    isa => 'Maybe[Str]',
);

=head2 ca_validity (Maybe[HashRef], optional)

When provided, the computed next-update time is compared to the CA
validity.  If next-update would exceed the CA lifetime the profile
switches to the C<lastcrl> validity interval defined in the profile.
The hashref must be usable with L<OpenXPKI::DateTime::get_validity>.

=cut

has ca_validity => (
    is  => 'ro',
    isa => 'Maybe[HashRef]',
);

=head2 validity (Maybe[HashRef], optional)

Optional override for the CRL validity (deprecated — will be removed).
When given, must be a hashref usable with L<OpenXPKI::DateTime::get_validity>.
Bypasses the validity defined in the profile configuration.

=cut

has validity => (
    is  => 'ro',
    isa => 'Maybe[HashRef]',
);

###########################################################################
# Internal resolved name

has _resolved_profile_name => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    builder  => '_build__resolved_profile_name',
    init_arg => undef,
);

###########################################################################
# Validity attributes

=head2 nextupdate_days (Int, lazy)

Number of full days until next CRL update.

=cut

has nextupdate_days => (
    reader   => 'get_nextupdate_in_days',
    isa      => 'Int',
    lazy     => 1,
    builder  => '_build_nextupdate_days',
    init_arg => undef,
);

=head2 nextupdate_hours (Int, lazy)

Remaining hours (0-23) until next CRL update after full days are subtracted.

=cut

has nextupdate_hours => (
    reader   => 'get_nextupdate_in_hours',
    isa      => 'Int',
    lazy     => 1,
    builder  => '_build_nextupdate_hours',
    init_arg => undef,
);

=head2 keep_expired (Maybe[ArrayRef[Str]], lazy)

List of reason codes whose revoked-but-expired certificates should remain
on the CRL, or C<undef> when not configured.

=cut

has keep_expired => (
    is       => 'ro',
    isa      => 'Maybe[ArrayRef[Str]]',
    lazy     => 1,
    builder  => '_build_keep_expired',
    init_arg => undef,
);

###########################################################################
# _profile_basepath implementation

sub _profile_basepath { ['crl', $_[0]->_resolved_profile_name] }

###########################################################################
# Public compatibility methods

=head1 METHODS

###########################################################################
# Builders

=cut

sub _build__resolved_profile_name {
    my $self = shift;
    return $self->profile_name if $self->profile_name;
    my $config = CTX('config');
    return $self->issuer_alias if $config->exists(['crl', $self->issuer_alias]);
    return 'default';
}

# Shared computation: returns (days, hours, notafter)
# Called by both _build_nextupdate_days and _build_nextupdate_hours via the
# cached _nextupdate_data attribute.
has _nextupdate_data => (
    is       => 'ro',
    isa      => 'HashRef',
    lazy     => 1,
    builder  => '_build__nextupdate_data',
    init_arg => undef,
);

sub _build__nextupdate_data {
    my $self   = shift;
    my $config = CTX('config');
    my $bp     = $self->_profile_basepath;

    OpenXPKI::Exception->throw(
        message => "Given CRL Profile not defined",
    ) if ($self->profile_name && !$config->exists(['crl', $self->profile_name]));

    # Determine validity — constructor override takes precedence over config
    my $validity;
    if ($self->validity) {
        $validity = $self->validity;
    } else {
        my $nextupdate_str = $config->get([@$bp, 'validity', 'nextupdate']);
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_PROFILE_CRL_LOAD_PROFILE_VALIDITY_NOTAFTER_NOT_DEFINED',
        ) unless $nextupdate_str;

        $validity = {
            VALIDITYFORMAT => 'relativedate',
            VALIDITY       => $nextupdate_str,
        };
    }

    my $notafter = OpenXPKI::DateTime::get_validity($validity);

    # CA end-of-life check
    if ($self->ca_validity) {
        my $ca_notafter = OpenXPKI::DateTime::get_validity($self->ca_validity);
        if ($notafter > $ca_notafter) {
            my $pki_realm       = CTX('session')->data->pki_realm;
            my $last_crl_str    = $config->get([@$bp, 'validity', 'lastcrl']);
            if (!$last_crl_str) {
                CTX('log')->application()->warn(
                    'CRL for CA ' . $self->issuer_alias
                    . ' in realm ' . $pki_realm
                    . ' will be end of life before next update is scheduled!'
                );
            } else {
                $notafter = OpenXPKI::DateTime::get_validity({
                    VALIDITYFORMAT => 'detect',
                    VALIDITY       => $last_crl_str,
                });
                CTX('log')->application()->info(
                    'CRL for CA ' . $self->issuer_alias
                    . ' in realm ' . $pki_realm
                    . ' nearly EOL - will issue with last crl interval!'
                );
            }
        }
    }

    my $hours = int(($notafter->epoch - time) / 3600);
    my $days  = int($hours / 24);
    $hours    = $hours % 24;

    return { days => $days, hours => $hours };
}

sub _build_nextupdate_days  { return $_[0]->_nextupdate_data->{days} }
sub _build_nextupdate_hours { return $_[0]->_nextupdate_data->{hours} }

sub _build_keep_expired {
    my $self   = shift;
    my $config = CTX('config');
    my $bp     = $self->_profile_basepath;
    my @keep   = $config->get_scalar_as_list([@$bp, 'keep_expired']);
    return @keep ? \@keep : undef;
}

__PACKAGE__->meta->make_immutable;
1;
__END__
