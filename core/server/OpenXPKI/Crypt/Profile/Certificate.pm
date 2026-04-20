package OpenXPKI::Crypt::Profile::Certificate;
use OpenXPKI -class;
use OpenXPKI::Types;

extends 'OpenXPKI::Crypt::Profile';
with 'OpenXPKI::Crypt::Profile::Role::Subject';
with 'OpenXPKI::Crypt::Profile::Role::SubjectAltName';

# Core modules
use DateTime;

# Project modules
use OpenXPKI::DateTime;
use OpenXPKI::DN;
use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Crypt::Profile::DTO::BasicConstraints;
use OpenXPKI::Crypt::Profile::DTO::KeyUsage;
use OpenXPKI::Crypt::Profile::DTO::ExtendedKeyUsage;
use OpenXPKI::Crypt::Profile::DTO::SubjectKeyIdentifier;
use OpenXPKI::Crypt::Profile::DTO::CRLDistributionPoints;
use OpenXPKI::Crypt::Profile::DTO::Policy;
use OpenXPKI::Crypt::Profile::DTO::PolicyIdentifier;
use OpenXPKI::Crypt::Profile::DTO::CustomOid;

my $_OCSP_NOCHECK_OID = '1.3.6.1.5.5.7.48.1.5';

=head1 NAME

OpenXPKI::Crypt::Profile::Certificate - Moose-based X.509 certificate profile

=head1 SYNOPSIS

  my $profile = OpenXPKI::Crypt::Profile::Certificate->new(
      profile_name => 'tls-server',
      issuer_alias => 'alpha-signer-1',
  );

  $profile->set_subject('CN=example.com,DC=example,DC=org');

  $profile->add_subject_alt_name(['DNS', 'example.com']);

  my $dt_notbefore = $profile->get_notbefore;
  my $dt_notafter  = $profile->get_notafter;

=head1 DESCRIPTION

Moose-based X.509 certificate profile.
Extends L<OpenXPKI::Crypt::Profile> with certificate-specific attributes and methods.

=head1 ATTRIBUTES

=head2 profile_name (Str, required)

Name of the certificate profile as defined in the realm configuration.

=cut

has profile_name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 copy_extensions (CopyExtensions, lazy, rw)

How to handle extensions from the CSR: C<none>, C<copy>, or C<copyall>.

=cut

has copy_extensions => (
    reader  => 'get_copy_extensions',
    isa     => 'CopyExtensions',
    lazy    => 1,
    builder => '_build_copy_extensions',
);

###########################################################################
# Validity

has _notafter_raw => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    builder  => '_build_notafter_raw',
    init_arg => undef,
);

=head2 notbefore (DateTime, lazy, rw)

Certificate validity start.

=cut

has notbefore => (
    is       => 'rw',
    isa      => 'DateTime',
    lazy     => 1,
    builder  => '_build_notbefore',
    clearer  => '_clear_notbefore',
    init_arg => undef,
);

=head2 notafter (DateTime, lazy, rw)

Certificate validity end.  When C<notafter> is configured as a relative
date, calling L</set_notbefore> clears the cached value so it is
recalculated relative to the new C<notbefore>.

=cut

has notafter => (
    is       => 'rw',
    isa      => 'DateTime',
    lazy     => 1,
    builder  => '_build_notafter',
    clearer  => '_clear_notafter',
    init_arg => undef,
);

###########################################################################
# Extension attributes (cert-specific)

=head2 basic_constraints (lazy, rw)

=cut

has basic_constraints => (
    is        => 'rw',
    isa       => 'OpenXPKI::Crypt::Profile::DTO::BasicConstraints',
    lazy      => 1,
    builder   => '_build_basic_constraints',
    predicate => 'has_basic_constraints',
    init_arg  => undef,
);

=head2 key_usage (Maybe[...], lazy, rw)

=cut

has key_usage => (
    is        => 'rw',
    isa       => 'Maybe[OpenXPKI::Crypt::Profile::DTO::KeyUsage]',
    lazy      => 1,
    builder   => '_build_key_usage',
    predicate => 'has_key_usage',
    init_arg  => undef,
);

=head2 extended_key_usage (Maybe[...], lazy, rw)

=cut

has extended_key_usage => (
    is        => 'rw',
    isa       => 'Maybe[OpenXPKI::Crypt::Profile::DTO::ExtendedKeyUsage]',
    lazy      => 1,
    builder   => '_build_extended_key_usage',
    predicate => 'has_extended_key_usage',
    init_arg  => undef,
);

=head2 subject_key_identifier (Maybe[...], lazy, rw)

=cut

has subject_key_identifier => (
    is        => 'rw',
    isa       => 'Maybe[OpenXPKI::Crypt::Profile::DTO::SubjectKeyIdentifier]',
    lazy      => 1,
    builder   => '_build_subject_key_identifier',
    predicate => 'has_subject_key_identifier',
    init_arg  => undef,
);

=head2 crl_distribution_points (Maybe[...], lazy, rw)

=cut

has crl_distribution_points => (
    is        => 'rw',
    isa       => 'Maybe[OpenXPKI::Crypt::Profile::DTO::CRLDistributionPoints]',
    lazy      => 1,
    builder   => '_build_crl_distribution_points',
    predicate => 'has_crl_distribution_points',
    init_arg  => undef,
);

=head2 policy_identifier (Maybe[...], lazy, rw)

=cut

has policy_identifier => (
    is        => 'rw',
    isa       => 'Maybe[OpenXPKI::Crypt::Profile::DTO::PolicyIdentifier]',
    lazy      => 1,
    builder   => '_build_policy_identifier',
    predicate => 'has_policy_identifier',
    init_arg  => undef,
);

=head2 ocsp_nocheck (Bool, lazy, rw)

=cut

has ocsp_nocheck => (
    is       => 'rw',
    isa      => 'Bool',
    lazy     => 1,
    builder  => '_build_ocsp_nocheck',
    init_arg => undef,
);

###########################################################################
# _profile_basepath implementation

sub _profile_basepath { ['profile', $_[0]->profile_name] }

###########################################################################
# Public methods

=head1 METHODS

=head2 set_notbefore($datetime)

Set the C<notbefore> date.  Clears the cached C<notafter> when notafter
is configured as a relative date.

=cut

sub set_notbefore {
    my ($self, $dt) = @_;
    $self->notbefore($dt);
    if (OpenXPKI::DateTime::is_relative($self->_notafter_raw)) {
        $self->_clear_notafter;
    }
    return $self;
}

=head2 get_notbefore

Returns a clone of the C<notbefore> DateTime.

=cut

sub get_notbefore {
    my $self = shift;
    return $self->notbefore->clone;
}


=head2 set_notafter($datetime)

Set the C<notafter> date.

=cut

sub set_notafter {
    my ($self, $dt) = @_;
    return $self->notafter($dt);
}


=head2 get_notafter

Returns a clone of the C<notafter> DateTime.

=cut

sub get_notafter {
    my $self = shift;
    return $self->notafter->clone;
}


###########################################################################
# Config serialisation API for OpenXPKI::Crypto::Backend::OpenSSL::Config

=head2 get_named_extensions

Extends the base class list with certificate-specific extensions.

=cut

sub get_named_extensions {
    my $self = shift;
    my @names = $self->SUPER::get_named_extensions();
    push @names, 'basic_constraints'        if $self->basic_constraints;
    push @names, 'key_usage'                if $self->key_usage;
    push @names, 'extended_key_usage'       if $self->extended_key_usage;
    push @names, 'subject_key_identifier'   if $self->subject_key_identifier;
    push @names, 'cdp'                      if $self->crl_distribution_points;
    push @names, 'policy_identifier'        if $self->policy_identifier;
    push @names, 'subject_alt_name'
        if $self->has_subject_alt_name && scalar @{ $self->subject_alt_name // [] };
    return @names;
}

=head2 is_critical_extension($name)

Handles cert-specific extension names, delegates shared ones to SUPER.

=cut

sub is_critical_extension {
    my ($self, $name) = @_;
    my %map = (
        basic_constraints      => sub { $self->basic_constraints },
        key_usage              => sub { $self->key_usage },
        extended_key_usage     => sub { $self->extended_key_usage },
        subject_key_identifier => sub { $self->subject_key_identifier },
        cdp                    => sub { $self->crl_distribution_points },
        policy_identifier      => sub { $self->policy_identifier },
    );
    if (my $getter = $map{$name}) {
        my $dto = $getter->($self) or return '';
        return $dto->critical ? 1 : '';
    }
    return $self->SUPER::is_critical_extension($name);
}

=head2 get_extension($name)

Handles cert-specific extension names, delegates shared ones to SUPER.

=cut

sub get_extension {
    my ($self, $name) = @_;

    if ($name eq 'basic_constraints') {
        my $dto = $self->basic_constraints or return [];
        my @val = (['CA', $dto->ca ? 'true' : 'false']);
        push @val, ['PATH_LENGTH', $dto->path_length] if defined $dto->path_length;
        return \@val;
    }
    elsif ($name eq 'key_usage') {
        my $dto = $self->key_usage or return [];
        return $dto->bits;
    }
    elsif ($name eq 'extended_key_usage') {
        my $dto = $self->extended_key_usage or return [];
        return $dto->usages;
    }
    elsif ($name eq 'subject_key_identifier') {
        return ['hash'];
    }
    elsif ($name eq 'cdp') {
        my $dto = $self->crl_distribution_points or return [];
        return $dto->uris;
    }
    elsif ($name eq 'policy_identifier') {
        my $dto = $self->policy_identifier or return [];
        return [map {
            ($_->cps || $_->user_notice)
                ? { oid => $_->oid, cps => $_->cps, user_notice => $_->user_notice }
                : $_->oid
        } @{ $dto->policies }];
    }
    elsif ($name eq 'subject_alt_name') {
        my $list = $self->subject_alt_name // [];
        return [map { [$_->type, $_->value] } @$list];
    }
    elsif ($name eq $_OCSP_NOCHECK_OID) {
        return $self->ocsp_nocheck ? ['ASN1:NULL'] : [];
    }
    return $self->SUPER::get_extension($name);
}

=head2 get_oid_extensions

Extends the base class list with the ocsp_nocheck OID when enabled.

=cut

sub get_oid_extensions {
    my $self = shift;
    my @oids = $self->SUPER::get_oid_extensions();
    push @oids, $_OCSP_NOCHECK_OID if $self->ocsp_nocheck;
    return @oids;
}

###########################################################################
# Builders — validity

sub _build_notafter_raw {
    my $self = shift;
    my $config = CTX('config');

    OpenXPKI::Exception->throw(message => 'Given profile does not exist')
        unless $config->exists(['profile', $self->profile_name]);

    my @path = ('profile', $self->profile_name, 'validity');
    @path = ('profile', 'default', 'validity') unless $config->exists(\@path);

    my $notafter = $config->get([@path, 'notafter']);
    OpenXPKI::Exception->throw(message => 'Profile has no notafter date defined')
        unless $notafter;

    return $notafter;
}

sub _build_notbefore {
    my $self = shift;
    my $config = CTX('config');

    OpenXPKI::Exception->throw(message => 'Given profile does not exist')
        unless $config->exists(['profile', $self->profile_name]);

    my @path = ('profile', $self->profile_name, 'validity');
    @path = ('profile', 'default', 'validity') unless $config->exists(\@path);

    my $notbefore = $config->get([@path, 'notbefore']);
    return $notbefore
        ? OpenXPKI::DateTime::get_validity({ VALIDITYFORMAT => 'detect', VALIDITY => $notbefore })
        : DateTime->now(time_zone => 'UTC');
}

sub _build_notafter {
    my $self = shift;
    my $raw = $self->_notafter_raw;

    if (OpenXPKI::DateTime::is_relative($raw)) {
        return OpenXPKI::DateTime::get_validity({
            REFERENCEDATE => $self->notbefore,
            VALIDITYFORMAT => 'relativedate',
            VALIDITY       => $raw,
        });
    } else {
        return OpenXPKI::DateTime::get_validity({
            VALIDITYFORMAT => 'absolutedate',
            VALIDITY       => $raw,
        });
    }
}

###########################################################################
# Builders — scalar settings

sub _build_copy_extensions {
    my $self = shift;
    my $config = CTX('config');
    return $config->get(['profile', $self->profile_name, 'extensions', 'copy'])
        // 'none';
}

###########################################################################
# Builders — cert-specific extensions

sub _build_basic_constraints {
    my $self = shift;

    # Always critical and defaults to false if nothing is set
    my $constraint = $self->_config_hash('basic_constraints');
    my $ca_val = $constraint->{ca}//0;

    return OpenXPKI::Crypt::Profile::DTO::BasicConstraints->new(
        critical    => 1,
        ca          => 0,
    ) unless ($ca_val =~ /\A(true|1)\z/);

    return OpenXPKI::Crypt::Profile::DTO::BasicConstraints->new(
        critical    => 1,
        ca          => 1,
        path_length => $constraint->{path_length},
    )

}

sub _build_key_usage {
    my $self = shift;
    my $bp = $self->_ext_basepath('key_usage') or return undef;
    my $config = CTX('config');

    my @all = qw(
        digital_signature  non_repudiation  key_encipherment  data_encipherment
        key_agreement  key_cert_sign  crl_sign  encipher_only  decipher_only
    );
    my @bits = grep { $config->get([@$bp, $_]) } @all;
    return undef unless @bits;

    return OpenXPKI::Crypt::Profile::DTO::KeyUsage->new(
        critical => $self->_read_critical($bp) // 0,
        bits     => \@bits,
    );
}

sub _build_extended_key_usage {
    my $self = shift;
    my $bp = $self->_ext_basepath('extended_key_usage') or return undef;
    my $config = CTX('config');

    my $hash  = $config->get_hash($bp) // {};
    my @named = qw(client_auth server_auth email_protection code_signing time_stamping ocsp_signing);
    my @usages = grep { $hash->{$_} } @named;
    push @usages, grep { /^\d+(\.\d+)+$/ } keys %$hash;
    return undef unless @usages;

    return OpenXPKI::Crypt::Profile::DTO::ExtendedKeyUsage->new(
        critical => $self->_read_critical($bp) // 0,
        usages   => \@usages,
    );
}

sub _build_subject_key_identifier {
    my $self = shift;
    my $bp = $self->_ext_basepath('subject_key_identifier') or return undef;
    return undef unless CTX('config')->get([@$bp, 'hash']);

    return OpenXPKI::Crypt::Profile::DTO::SubjectKeyIdentifier->new(
        critical => $self->_read_critical($bp) // 0,
    );
}

sub _build_crl_distribution_points {
    my $self = shift;
    my $bp = $self->_ext_basepath('crl_distribution_points') or return undef;
    my $config = CTX('config');

    my @uris = $config->get_scalar_as_list([@$bp, 'uri']);
    @uris = @{ $self->process_templates(\@uris) };
    return undef unless @uris;

    return OpenXPKI::Crypt::Profile::DTO::CRLDistributionPoints->new(
        critical => $self->_read_critical($bp) // 0,
        uris     => \@uris,
    );
}

sub _build_policy_identifier {
    my $self = shift;
    my $bp = $self->_ext_basepath('policy_identifier') or return undef;
    my $config = CTX('config');

    my @policies;

    my @oids = grep { /\d+(\.\d+)+/ }
        $config->get_scalar_as_list([@$bp, 'oid']);

    if (@oids == 1) {
        my @parent = @$bp;
        pop @parent;
        my @notice = $config->get_scalar_as_list([@parent, 'user_notice']);
        if (@notice) {
            push @policies, OpenXPKI::Crypt::Profile::DTO::Policy->new(
                oid         => $oids[0],
                user_notice => \@notice,
            );
        } else {
            push @policies, OpenXPKI::Crypt::Profile::DTO::Policy->new(oid => $oids[0]);
        }
    } elsif (@oids > 1) {
        push @policies, map {
            OpenXPKI::Crypt::Profile::DTO::Policy->new(oid => $_)
        } @oids;
    }

    for my $name ($config->get_keys($bp)) {
        next unless $name =~ /\d+(\.\d+)+/;
        my @cps    = $config->get_scalar_as_list([@$bp, $name, 'cps']);
        my @notice = $config->get_scalar_as_list([@$bp, $name, 'user_notice']);
        push @policies, OpenXPKI::Crypt::Profile::DTO::Policy->new(
            oid         => $name,
            cps         => (@cps    ? \@cps    : undef),
            user_notice => (@notice ? \@notice : undef),
        );
    }

    return undef unless @policies;

    return OpenXPKI::Crypt::Profile::DTO::PolicyIdentifier->new(
        critical => $self->_read_critical($bp) // 0,
        policies => \@policies,
    );
}

sub _build_ocsp_nocheck {
    my $self = shift;
    my $bp = $self->_ext_basepath('ocsp_nocheck') or return 0;
    return CTX('config')->get($bp) ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;
1;
__END__
