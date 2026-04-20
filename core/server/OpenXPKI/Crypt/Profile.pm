package OpenXPKI::Crypt::Profile;
use OpenXPKI -class;
use OpenXPKI::Types;

# Core modules
use DateTime;
use OpenXPKI::Template;

# Project modules
use OpenXPKI::DateTime;
use OpenXPKI::DN;
use OpenXPKI::Crypt::X509;
use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Crypt::Profile::DTO::AuthorityKeyIdentifier;
use OpenXPKI::Crypt::Profile::DTO::IssuerAltName;
use OpenXPKI::Crypt::Profile::DTO::AuthorityInfoAccess;
use OpenXPKI::Crypt::Profile::DTO::CustomOid;

=head1 NAME

OpenXPKI::Crypt::Profile - Abstract base class for Moose-based X.509 profiles

=head1 DESCRIPTION

Base class shared by L<OpenXPKI::Crypt::Profile::Certificate> and
L<OpenXPKI::Crypt::Profile::CRL>.  Holds the issuer identity, digest,
string-mask and padding settings, the serial number, and the extensions that
appear in both certificate and CRL profiles (authorityInfoAccess,
authorityKeyIdentifier, issuerAltName, and custom OIDs).

Subclasses must implement L</_profile_basepath>.

=head1 ATTRIBUTES

=head2 issuer_alias (Str, required)

Alias of the CA token to use from the alias table.

=cut

has issuer_alias => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 issuer_cert (OpenXPKI::Crypt::X509, lazy)

OpenXPKI::Crypt::X509 object of the issuer certificate, lazy loaded via
L<get_certificate_for_alias>.

=cut

has issuer_cert => (
    is      => 'ro',
    isa     => 'OpenXPKI::Crypt::X509',
    lazy    => 1,
    builder => '_load_issuer_cert',
);

###########################################################################
# Scalar profile attributes

=head2 digest (Str, lazy)

Hash algorithm for the signature (default: C<sha256>).

=cut

has digest => (
    reader  => 'get_digest',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_digest',
);

=head2 string_mask (Str, lazy)

OpenSSL string mask for DN encoding (default: C<utf8only>).

=cut

has string_mask => (
    reader  => 'get_string_mask',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_string_mask',
);

=head2 padding (Maybe[HashRef], lazy)

RSA/EC padding configuration hash.  C<undef> when not configured.

=cut

has padding => (
    reader  => 'get_padding',
    isa     => 'Maybe[HashRef]',
    lazy    => 1,
    builder => '_build_padding',
);

=head2 serial (Maybe[Str], rw)

Serial number (decimal string).  Used for both certificates and CRLs.

=cut

has serial => (
    is       => 'rw',
    isa      => 'Maybe[Str]',
    writer   => 'set_serial',
    reader   => 'get_serial',
    init_arg => undef,
);

###########################################################################
# Extension attributes shared between Certificate and CRL

=head2 authority_key_identifier (Maybe[...], lazy, rw)

=cut

has authority_key_identifier => (
    is        => 'rw',
    isa       => 'Maybe[OpenXPKI::Crypt::Profile::DTO::AuthorityKeyIdentifier]',
    lazy      => 1,
    builder   => '_build_authority_key_identifier',
    predicate => 'has_authority_key_identifier',
    init_arg  => undef,
);

=head2 issuer_alt_name (Maybe[...], lazy, rw)

=cut

has issuer_alt_name => (
    is        => 'rw',
    isa       => 'Maybe[OpenXPKI::Crypt::Profile::DTO::IssuerAltName]',
    lazy      => 1,
    builder   => '_build_issuer_alt_name',
    predicate => 'has_issuer_alt_name',
    init_arg  => undef,
);

=head2 authority_info_access (Maybe[...], lazy, rw)

=cut

has authority_info_access => (
    is        => 'rw',
    isa       => 'Maybe[OpenXPKI::Crypt::Profile::DTO::AuthorityInfoAccess]',
    lazy      => 1,
    builder   => '_build_authority_info_access',
    predicate => 'has_authority_info_access',
    init_arg  => undef,
);

=head2 custom_oids (ArrayRef[...CustomOid], lazy, rw)

Custom OID extensions from the C<oid> configuration section.

=cut

has custom_oids => (
    is       => 'rw',
    isa      => 'ArrayRef[OpenXPKI::Crypt::Profile::DTO::CustomOid]',
    lazy     => 1,
    builder  => '_build_custom_oids',
    init_arg => undef,
);

###########################################################################
# Public methods

=head1 METHODS

=head2 add_custom_oid(\%ext)

Accepts a hashref with keys C<oid>, C<critical>, C<value> (scalar) or
C<section> (multi-line SEQUENCE) and appends a
L<OpenXPKI::Crypt::Profile::DTO::CustomOid> object to L</custom_oids>.

Throws an exception if the OID falls in the C<2.5.29.*> range (standard
X.509v3 extensions that must not be overridden externally).

=cut

sub add_custom_oid {
    my ($self, $ext) = @_;
    my $oid = $ext->{oid};
    if ($oid =~ /^0*2\.0*5\.0*29\./) {
        OpenXPKI::Exception->throw(
            message => 'Extensions in OID namespace 2.5.29 are not allowed',
            params  => { OID => $oid },
        );
    }
    my $dto;

    # RenderExtensions and other legacy codes creates an array ref where
    # the first line is the right hand part of the config line and the
    # remainder is the section content, likely including addtional section
    # headers. We try to detect this here and do some basic validation.
    # CAVEAT: this might not be compatible with anything our customers did
    if (ref $ext->{value} eq '' && $ext->{value} ne '') {
        $dto = OpenXPKI::Crypt::Profile::DTO::CustomOid->new(
            oid      => $oid,
            critical => $ext->{critical} ? 1 : 0,
            value    => $ext->{value},
        );

    } elsif (ref $ext->{value} eq 'ARRAY') {

        my @val = $ext->{value}->@*;
        return unless @val;

        # this MUST be ASN1:SEQUENCE:section_head_name
        my $first = shift @val;
        OpenXPKI::Exception->throw(
            message => 'Multiline extensions must use section or start first line with ASN1:SEQUENCE',
            params  => { value => $val[0] },
        ) unless (substr($first,0,14) eq 'ASN1:SEQUENCE:');

        for my $line (@val) {

            # section header is allowed here
            next if ( $line =~ m{\A\[\x20*\w+\x20*\]\z} );

            # content line must start with fieldX=
            # and not contain anything special chars on the right
            next if ( $line =~ m{\Afield\d+\x20*=[\x20-\x7F]+\z});

            OpenXPKI::Exception->throw(
                message => 'Found invalid line in multiline extensions',
                params  => { line => $line },
            );

        }
        $dto = OpenXPKI::Crypt::Profile::DTO::CustomOid->new(
            oid           => $oid,
            critical      => $ext->{critical} ? 1 : 0,
            value         => \@val,
            encoding      => 'SEQUENCE',
            section_name  => substr($first,14),
        );

    } elsif ($ext->{section}) {

        my @val = (ref $ext->{section} eq '')
            ? split /\r?\n/, $ext->{section}
            : $ext->{section}->@*;

        for my $line (@val) {
            OpenXPKI::Exception->throw(
                message => 'Found invalid line in multiline section',
                params  => { line => $line },
            ) unless ( $line =~ m{\Afield\d+\x20*=[\x20-\x7F]+\z});
        }

        $dto = OpenXPKI::Crypt::Profile::DTO::CustomOid->new(
            oid           => $oid,
            critical      => $ext->{critical} ? 1 : 0,
            value         => \@val,
            encoding      => 'SEQUENCE',
        );
    }
    return $self unless $dto;
    $self->custom_oids([ @{ $self->custom_oids }, $dto ]);
    return $self;
}

=head2 process_templates(\@values)

Process Template Toolkit tags in the given list of strings.  Returns an
ArrayRef with processed values.

=cut

sub process_templates {
    my ($self, $values) = @_;

    return $values unless scalar grep { /\[.*\]/ } @$values;

    my $tt   = OpenXPKI::Template->new();
    my $x509 = $self->issuer_cert;

    my $issuer_info = $x509->subject_hash();
    $issuer_info->{DN} = $x509->get_subject();

    $self->issuer_alias =~ /^(.*)-(\d+)$/;
    my ($group, $generation) = ($1, $2);

    my %vars = (
        ISSUER     => $issuer_info,
        CAALIAS    => { ALIAS => $self->issuer_alias, GROUP => $group, GENERATION => $generation },
        ALIAS      => $self->issuer_alias,
        GROUP      => $group,
        GENERATION => $generation,
        PKI_REALM  => CTX('api2')->get_pki_realm(),
    );

    my @result;
    for my $tpl (@$values) {
        if ($tpl =~ /\[.+\]/) {
            my $output = $tt->render($tpl, \%vars);
            push @result, $output;
        } else {
            push @result, $tpl;
        }
    }
    return \@result;
}

###########################################################################
# Config serialisation API for OpenXPKI::Crypto::Backend::OpenSSL::Config
# Shared extensions only — Certificate subclass extends these.

=head2 get_named_extensions

Returns the list of named extension identifiers that are currently set.
Covers the extensions common to both Certificate and CRL profiles.
L<OpenXPKI::Crypt::Profile::Certificate> calls C<SUPER> and appends
cert-specific extensions.

=cut

sub get_named_extensions {
    my $self = shift;
    my @names;
    push @names, 'authority_key_identifier' if $self->authority_key_identifier;
    push @names, 'issuer_alt_name'          if $self->issuer_alt_name;
    push @names, 'authority_info_access'    if $self->authority_info_access;
    return @names;
}

=head2 is_critical_extension($name)

Returns 1 if the named (or OID) extension is marked critical, C<''> otherwise.

=cut

sub is_critical_extension {
    my ($self, $name) = @_;
    my %map = (
        authority_key_identifier => sub { $_[0]->authority_key_identifier },
        issuer_alt_name          => sub { $_[0]->issuer_alt_name },
        authority_info_access    => sub { $_[0]->authority_info_access },
    );
    if (my $getter = $map{$name}) {
        my $dto = $getter->($self) or return '';
        return $dto->critical ? 1 : '';
    }
    # OID extension
    my ($dto) = grep { $_->oid eq $name } @{ $self->custom_oids };
    return '' unless $dto;
    return $dto->critical ? 1 : '';
}

=head2 get_extension($name)

Returns extension data in the array/hashref format expected by
L<OpenXPKI::Crypto::Backend::OpenSSL::Config>.

=cut

sub get_extension {
    my ($self, $name) = @_;

    if ($name eq 'authority_key_identifier') {
        my $dto = $self->authority_key_identifier or return [];
        my @val;
        push @val, 'keyid'  if $dto->keyid;
        push @val, 'issuer' if $dto->issuer;
        return \@val;
    }
    elsif ($name eq 'issuer_alt_name') {
        return ['copy'];
    }
    elsif ($name eq 'authority_info_access') {
        my $dto = $self->authority_info_access or return [];
        my @val;
        push @val, ['CA_ISSUERS', $dto->ca_issuers] if $dto->ca_issuers;
        push @val, ['OCSP',       $dto->ocsp]       if $dto->ocsp;
        return \@val;
    }
    # Dotted-decimal OID — look up in custom_oids
    my ($dto) = grep { $_->oid eq $name } @{ $self->custom_oids };
    return [] unless $dto;
    return [$dto->value, $dto->is_sequence ? @{ $dto->section_lines } : ()];
}

=head2 get_oid_extensions

Returns the list of custom OID strings (dotted-decimal) currently set.

=cut

sub get_oid_extensions {
    my $self = shift;
    return map { $_->oid } @{ $self->custom_oids };
}

###########################################################################
# Abstract — must be implemented by subclasses

=head2 _profile_basepath

Returns an ArrayRef of config path components identifying the profile
section, e.g. C<['profile', 'tls-server']> or C<['crl', 'default']>.
The first element serves as the namespace prefix for the default fallback.
Must be overridden by subclasses.

=cut

sub _profile_basepath {
    die ref($_[0]) . ' must implement _profile_basepath';
}

###########################################################################
# Private helpers

sub _load_issuer_cert {
    my $self = shift;
    my $cert = CTX('api2')->get_certificate_for_alias(alias => $self->issuer_alias);
    OpenXPKI::Exception->throw(
        message => 'Unable to load CA Certificate via API'
    ) unless $cert;
    return OpenXPKI::Crypt::X509->new($cert->{data});
}

sub _config_scalar {
    my ($self, $key) = @_;
    my $bp = $self->_profile_basepath;
    my $config = CTX('config');
    return $config->get([@$bp, $key])
        // $config->get([$bp->[0], 'default', $key]);
}

sub _config_hash {
    my ($self, $key) = @_;
    my $bp = $self->_profile_basepath;
    my $config = CTX('config');
    return $config->get_hash([@$bp, $key])
        // $config->get_hash([$bp->[0], 'default', $key]);
}

sub _ext_basepath {
    my ($self, $ext) = @_;
    my $bp = $self->_profile_basepath;
    my $config = CTX('config');

    my @path = (@$bp, 'extensions', $ext);
    return \@path if $config->exists(\@path);

    @path = ($bp->[0], 'default', 'extensions', $ext);
    return \@path if $config->exists(\@path);

    return undef;
}

sub _read_critical {
    my ($self, $basepath) = @_;
    my $val = CTX('config')->get([@$basepath, 'critical']);
    return undef unless defined $val;
    return $val ? 1 : 0;
}

###########################################################################
# Builders

sub _build_digest {
    my $self = shift;
    return $self->_config_scalar('digest') // 'sha256';
}

sub _build_string_mask {
    my $self = shift;
    return $self->_config_scalar('string_mask') // 'utf8only';
}

sub _build_padding {
    my $self = shift;
    return $self->_config_hash('padding');
}

sub _build_authority_key_identifier {
    my $self = shift;
    my $bp = $self->_ext_basepath('authority_key_identifier') or return undef;
    my $config = CTX('config');

    my $keyid  = $config->get([@$bp, 'keyid'])  ? 1 : 0;
    my $issuer = $config->get([@$bp, 'issuer']) ? 1 : 0;
    return undef unless $keyid || $issuer;

    return OpenXPKI::Crypt::Profile::DTO::AuthorityKeyIdentifier->new(
        critical => $self->_read_critical($bp) // 0,
        keyid    => $keyid,
        issuer   => $issuer,
    );
}

sub _build_issuer_alt_name {
    my $self = shift;
    my $bp = $self->_ext_basepath('issuer_alt_name') or return undef;
    return undef unless CTX('config')->get([@$bp, 'copy']);

    return OpenXPKI::Crypt::Profile::DTO::IssuerAltName->new(
        critical => $self->_read_critical($bp) // 0,
    );
}

sub _build_authority_info_access {
    my $self = shift;
    my $bp = $self->_ext_basepath('authority_info_access') or return undef;
    my $config = CTX('config');

    my %aia;
    for my $bit (qw(ca_issuers ocsp)) {
        my @tpl = $config->get_scalar_as_list([@$bp, $bit]);
        $aia{$bit} = $self->process_templates(\@tpl) if @tpl;
    }
    return undef unless %aia;

    return OpenXPKI::Crypt::Profile::DTO::AuthorityInfoAccess->new(
        critical   => $self->_read_critical($bp) // 0,
        ca_issuers => $aia{ca_issuers},
        ocsp       => $aia{ocsp},
    );
}

sub _build_custom_oids {
    my $self = shift;
    my $config = CTX('config');
    my $bp = $self->_profile_basepath;
    my @oid_bp = (@$bp, 'extensions', 'oid');
    unless ($config->exists(\@oid_bp)) {
        @oid_bp = ($bp->[0], 'default', 'extensions', 'oid');
        return [] unless $config->exists(\@oid_bp);
    }

    my @result;
    for my $name ($config->get_keys(\@oid_bp)) {
        my $attr = $config->get_hash([@oid_bp, $name]);
        next unless $attr->{value};

        my $oid      = $attr->{oid} // $name;
        my $critical = $attr->{critical} ? 1 : 0;
        push @result, OpenXPKI::Crypt::Profile::DTO::CustomOid->new(
            oid           => $oid,
            critical      => $critical,
            value         => $attr->{value},
            encoding      => $attr->{encoding}//'',
            format        => $attr->{format}//'',
        );
    }
    return \@result;
}

__PACKAGE__->meta->make_immutable;
1;
__END__
