package OpenXPKI::Crypt::X509;
use OpenXPKI -class;

with 'OpenXPKI::Role::CertAndReqParser';

use Digest::SHA qw(sha1_hex);
use OpenXPKI::DateTime;
use OpenXPKI::Crypt::DN;

sub _asn1_root_node { 'Certificate'  }
sub _pem_type       { 'CERTIFICATE'  }

sub get_cert_identifier { shift->get_identifier() }

has db_hash => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_to_db_hash',
);

has issuer => (
    is       => 'ro',
    init_arg => undef,
    isa      => 'Str',
    reader   => 'get_issuer',
    lazy     => 1,
    default  => sub {
        my $self = shift;
        my $rdn = $self->_parsed->{tbsCertificate}{issuer}{rdnSequence};
        return OpenXPKI::Crypt::DN->new(sequence => $rdn)->get_subject();
    }
);

sub get_issuer_rdn { return shift->_parsed->{tbsCertificate}{issuer}{rdnSequence} }

has authority_key_id => (
    is      => 'ro',
    init_arg => undef,
    isa     => 'Str|Undef',
    reader  => 'get_authority_key_id',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $der = $self->_get_ext_der('2.5.29.35') or return undef;
        my $aki = $self->_asn1('AuthorityKeyIdentifier')->decode($der) or return undef;
        return undef unless $aki->{keyIdentifier};
        return uc join ':', (unpack '(A2)*', unpack 'H*', $aki->{keyIdentifier});
    }
);

has notbefore => (
    is      => 'ro',
    init_arg => undef,
    isa     => 'Int',
    lazy    => 1,
    default => sub { _asn1_time_to_epoch(shift->_parsed->{tbsCertificate}{validity}{notBefore}) }
);

has notafter => (
    is      => 'ro',
    init_arg => undef,
    isa     => 'Int',
    lazy    => 1,
    default => sub { _asn1_time_to_epoch(shift->_parsed->{tbsCertificate}{validity}{notAfter}) }
);

has serial => (
    is      => 'ro',
    init_arg => undef,
    isa     => 'Str',
    reader  => 'get_serial',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $serial = $self->_parsed->{tbsCertificate}{serialNumber};
        $serial = $serial->bstr() if ref $serial eq 'Math::BigInt';
        return "$serial";
    }
);

has cdp => (
    is      => 'ro',
    init_arg => undef,
    isa     => 'ArrayRef',
    reader  => 'get_cdp',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $der = $self->_get_ext_der('2.5.29.31') or return [];
        my $dps = $self->_asn1('CRLDistributionPoints')->decode($der) or return [];
        my @uris;
        for my $dp (@$dps) {
            next unless $dp->{distributionPoint};
            my $dpname = $self->_asn1('DistributionPointName')->decode($dp->{distributionPoint});
            next unless $dpname && $dpname->{fullName};
            for my $gn (@{$dpname->{fullName}}) {
                push @uris, $gn->{uniformResourceIdentifier}
                    if $gn->{uniformResourceIdentifier};
            }
        }
        return \@uris;
    }
);

=head2 get_authority_info

Returns a hash reference with keys C<caIssuer> and C<ocsp>, each containing
an array reference of URIs parsed from the Authority Information Access extension.

=cut

has authority_info => (
    is      => 'ro',
    init_arg => undef,
    isa     => 'HashRef',
    reader  => 'get_authority_info',
    lazy    => 1,
    builder => '_build_authority_info',
);

=head2 get_subject_info_access

Returns a HashRef keyed by accessMethod OID, each value an ArrayRef of URI strings,
parsed from the SubjectInfoAccess extension (OID 1.3.6.1.5.5.7.1.11).

=cut

has subject_info_access => (
    is       => 'ro',
    init_arg => undef,
    isa      => 'HashRef',
    reader   => 'get_subject_info_access',
    lazy     => 1,
    builder  => '_build_subject_info_access',
);

=head1 METHODS

=head2 get_notbefore / get_notafter I<format>

Returns the notbefore / notafter date in the given format. For allowed
formats see OpenXPKI::DateTime::convert_date, without format a DateTime
object is returned.

=cut

sub get_notbefore {
    my $self = shift;
    return $self->_get_validity($self->notbefore(), shift);
}

sub get_notafter {
    my $self = shift;
    return $self->_get_validity($self->notafter(), shift);
}

=head2 is_selfsigned

Returns true if the certificate is self-signed.

Note: the check is done via subject/authority key identifier or by DN comparison,
not on a cryptographic level.

=cut

sub is_selfsigned {
    my $self = shift;
    if ($self->get_authority_key_id() && $self->get_subject_key_id()) {
        return $self->get_authority_key_id() eq $self->get_subject_key_id();
    }
    return $self->get_issuer eq $self->get_subject;
}

=head2 is_ca

Returns true if the certificate has the keyUsage keyCertSign and
BasicConstraints "cA" set (critical), false otherwise.

=cut

sub is_ca {
    my $self = shift;
    my $ku = $self->get_key_usage() or return 0;
    return 0 unless grep { $_ eq 'keyCertSign' } @{$ku->bits};
    my $bc = $self->get_basic_constraints() or return 0;
    return ($bc->ca && $bc->critical) ? 1 : 0;
}

sub _build_authority_info {
    my $self = shift;
    my $der = $self->_get_ext_der('1.3.6.1.5.5.7.1.1')
        or return { caIssuer => [], ocsp => [] };
    my $decoded = $self->_asn1('AuthorityInfoAccess')->decode($der)
        or return { caIssuer => [], ocsp => [] };
    my %raw;
    for my $desc (@$decoded) {
        next unless $desc->{accessLocation}{uniformResourceIdentifier};
        push @{$raw{$desc->{accessMethod}}}, $desc->{accessLocation}{uniformResourceIdentifier};
    }
    return {
        caIssuer => $raw{'1.3.6.1.5.5.7.48.2'} // [],
        ocsp     => $raw{'1.3.6.1.5.5.7.48.1'} // [],
    };
}

sub _build_subject_info_access {
    my $self = shift;
    my $der = $self->_get_ext_der('1.3.6.1.5.5.7.1.11') or return {};
    my $decoded = $self->_asn1('AuthorityInfoAccess')->decode($der) or return {};
    my %result;
    for my $desc (@$decoded) {
        next unless $desc->{accessLocation}{uniformResourceIdentifier};
        push @{$result{$desc->{accessMethod}}}, $desc->{accessLocation}{uniformResourceIdentifier};
    }
    return \%result;
}

sub _get_validity {
    my $self   = shift;
    my $date   = shift;
    my $format = shift || '';

    return $date if $format eq 'epoch';

    $date = DateTime->from_epoch(epoch => $date);
    return $date unless $format;

    return OpenXPKI::DateTime::convert_date({
        DATE      => $date,
        OUTFORMAT => $format,
    });
}

# Convert::ASN1 decodes UTCTime/GeneralizedTime as epoch integers inside a CHOICE hashref.
sub _asn1_time_to_epoch {
    my $time = shift;
    return $time->{generalTime} // $time->{utcTime};
}

sub _to_db_hash {
    my $self = shift;
    return {
        cert_key                 => $self->get_serial(),
        identifier               => $self->get_cert_identifier(),
        data                     => $self->pem(),
        subject                  => $self->get_subject(),
        issuer_dn                => $self->get_issuer(),
        subject_key_identifier   => $self->get_subject_key_id(),
        authority_key_identifier => $self->get_authority_key_id(),
        notafter                 => $self->notafter(),
        notbefore                => $self->notbefore(),
    };
}

__PACKAGE__->meta->make_immutable;

__END__;
