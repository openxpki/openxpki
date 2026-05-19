package OpenXPKI::Crypt::X509;
use OpenXPKI -class;

# imports the decode_tag and parser
with 'OpenXPKI::Role::ASN1Parse';

use Digest::SHA qw(sha1_base64 sha1_hex);
use OpenXPKI::DateTime;
use MIME::Base64;
use Crypt::X509 0.53;

use OpenXPKI::Crypt::DN;

has data => (
    is => 'ro',
    required => 1,
    isa => 'Str',
);

has pem => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        # convert DER to PEM
        my $pem = encode_base64($self->data(), '');
        $pem =~ s{ (.{64}) }{$1\n}xmsg;
        chomp $pem;
        return "-----BEGIN CERTIFICATE-----\n$pem\n-----END CERTIFICATE-----";
    },
);

has db_hash => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_to_db_hash',
);

has _cert => (
    is => 'ro',
    required => 1,
    isa => 'Crypt::X509',
);

has cert_identifier => (
    is => 'rw',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_cert_identifier',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $cert_identifier = sha1_base64($self->data);
        ## RFC 3548 URL and filename safe base64
        $cert_identifier =~ tr/+\//-_/;
        return $cert_identifier;
    },
);

has subject => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_subject',
    lazy => 1,
    default => sub {
        my $self = shift;
        return join ",", map {
            # Replace S -> ST and l => L, see #674
            $_ =~ s{\AS=}{ST=}; $_ =~ s{\Al=}{L=}; $_
        } reverse @{$self->_cert()->Subject};
    }
);

has subject_hash => (
    is => 'ro',
    init_arg => undef,
    isa => 'HashRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $hash = {};
        foreach my $comp (reverse @{$self->_cert()->Subject}) {
            my ($k,$v) = split("=", $comp);
            # Replace S -> ST and l => L, see #674
            $k =~ s{\AS=}{ST=};
            $k =~ s{\Al=}{L=};
            $hash->{$k} = [] unless($hash->{$k});
            push @{$hash->{$k}}, $v;
        }
        return $hash;
    }
);

has cert_subject_parts => (
    is => 'ro',
    init_arg => undef,
    isa => 'HashRef',
    lazy => 1,
    reader => 'get_cert_subject_parts',
    builder => '_build_cert_subject_parts_hash'
);

=head2

Returns a pointer to a list of SANs. Each SAN is represented as a pointer to a list
containing two items - the SAN type (IP, DNS, dirName, etc.) and its value. The value
is represented in its decoded ASN.1 form.

Example return value:

  [
    [ "DNS", "example.com" ],
    [ "email", "foo@example.com" ]
  ]

=cut

has subject_alt_name => (
    is => 'ro',
    init_arg => undef,
    isa => 'ArrayRef',
    reader => 'get_subject_alt_name',
    lazy => 1,
    builder => '_build_san'
);

has issuer => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_issuer',
    lazy => 1,
    default => sub {
        my $self = shift;
        return join ",", map {
            # Replace S -> ST and l => L, see #674
            $_ =~ s{\AS=}{ST=}; $_ =~ s{\Al=}{L=}; $_
        } reverse @{$self->_cert()->Issuer};
    }
);

has subject_key_id => (
    is => 'rw',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_subject_key_id',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $keyid = $self->_cert()->subject_keyidentifier();
        if ($keyid) {
            return uc join ':', ( unpack '(A2)*', unpack 'H*', $keyid );
        }
        return $self->get_public_key_hash();
    }
);

has public_key_hash => (
    is => 'rw',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_public_key_hash',
    lazy => 1,
    default => sub {
        my $self = shift;
        return uc join ':', ( unpack '(A2)*', sha1_hex( $self->_cert()->pubkey() ));
    }
);

has public_key_alg => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_public_key_alg',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->_cert()->PubKeyAlg();
    }
);

has authority_key_id => (
    is => 'rw',
    init_arg => undef,
    isa => 'Str|Undef',
    reader => 'get_authority_key_id',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $keyid = $self->_cert()->key_identifier();
        # Auth-Info can be a hash -> not supported yet
        if (!$keyid || ref $keyid ne '') {
            return undef;
        }
        return uc join ':', ( unpack '(A2)*', ( unpack 'H*', $keyid ) );
    }
);

has notbefore => (
    is => 'ro',
    init_arg => undef,
    isa => 'Int',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->_cert()->not_before();
    }
);

has notafter => (
    is => 'ro',
    init_arg => undef,
    isa => 'Int',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->_cert()->not_after();
    }
);

has serial => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_serial',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $serial = $self->_cert()->serial;
        if (ref $serial eq 'Math::BigInt') {
            $serial = $serial->bstr();
        }
        return $serial;
    }
);

has cdp => (
    is => 'ro',
    init_arg => undef,
    isa => 'ArrayRef',
    reader => 'get_cdp',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->_cert()->CRLDistributionPoints();
    }
);

has key_usage => (
    is => 'ro',
    init_arg => undef,
    isa => 'ArrayRef',
    reader => 'get_key_usage',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->_cert->KeyUsage() // [];
    }
);

has ext_key_usage => (
    is => 'ro',
    init_arg => undef,
    isa => 'ArrayRef',
    reader => 'get_ext_key_usage',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->_cert->ExtKeyUsage() // [];
    }
);

=head2 get_basic_constraints

Returns a hash reference with keys C<ca> (0 or 1), C<critical> (0 or 1),
and C<pathlen> (integer or C<undef> if not set).

=cut

has basic_constraints => (
    is => 'ro',
    init_arg => undef,
    isa => 'HashRef',
    reader => 'get_basic_constraints',
    lazy => 1,
    builder => '_build_basic_constraints',
);

=head2 get_aia

Returns a hash reference with keys C<caIssuer> and C<ocsp>, each containing
an array reference of URIs parsed from the Authority Information Access extension.

=cut

has authority_info => (
    is => 'ro',
    init_arg => undef,
    isa => 'HashRef',
    reader => 'get_authority_info',
    lazy => 1,
    builder => '_build_authority_info',
);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;
    my $data = shift;

    if ($data =~ m{-----BEGIN[^-]*CERTIFICATE-----(.+?)-----END[^-]*CERTIFICATE-----}xms ) {
        $data = decode_base64($1);
    }

    my $cert = Crypt::X509->new( cert => $data );
    if ($cert->error) {
        die $cert->error;
    }

    return $class->$orig( data => $data, _cert => $cert );

};

=head1 METHODS

=head2 cn

Get the value of the subject CN field.

=cut

sub cn {
    my $self = shift;
    return $self->subject_hash()->{CN}->[0];
}

=head2 get_notbefore / get_notafter I<format>

Returns the notbefore / notafter date in the given format. For allowed
formats see OpenXPKI::DateTime::convert_date, without format a DateTime
object is returned.

=cut

sub get_notbefore {
    my $self = shift;
    return $self->_get_validity( $self->notbefore(), shift );
}

sub get_notafter {
    my $self = shift;
    return $self->_get_validity( $self->notafter(), shift );
}

=head2 is_selfsigned

returns true if the certificate is self-signed.

Note: the check is (currently) done the subject/authority key identifier
or by a comparison of subject and issuer DN and not on a cryptographic
level - so there might be situations where this is not accurate.

=cut

sub is_selfsigned {

    my $self = shift;
    # todo - calculate signature might be better
    if ($self->get_authority_key_id() && $self->get_subject_key_id()) {
        return $self->get_authority_key_id() eq $self->get_subject_key_id();
    }
    return $self->get_issuer eq $self->get_subject;

}

=head2 is_ca

returns true if the certificate has the keyUsage keyCertSign and
BasicConstraints "cA" set (critical), false otherwise.

=cut

sub is_ca {

    my $self = shift;

    return 0 unless (grep { $_ eq 'keyCertSign' } @{$self->get_key_usage()});

    my $bc = $self->get_basic_constraints();
    return ($bc->{ca} && $bc->{critical}) ? 1 : 0;
}

sub _build_san {

    my $self = shift;

    my $san_map = {
        otherName => 'otherName',
        rfc822Name => 'email',
        dNSName => 'DNS',
        x400Address => '', # not supported by openssl
        directoryName => 'dirName',
        ediPartyName => '', # not supported by openssl
        uniformResourceIdentifier => 'URI',
        iPAddress  => 'IP',
        registeredID => 'RID',
    };

    my @san_list;
    my $san_exts = $self->_cert->DecodedSubjectAltNames();

	# Walk through all the extensions (though there really should be only)
    foreach my $san_ext (@$san_exts) {
        # Walk through all the names in the extension
        foreach my $name (@$san_ext) {
            # Walk through the keys of the name (there should only be one)
            foreach my $type (keys %{$name}) {
                my $san_type = $san_map->{$type};
                next unless($san_type);
                my $san_val = $name->{$type};
                # IPs are raw byte sequence, copied from Crypt::PKCS10
                if ($type eq 'iPAddress') {
                    if( length $san_val == 4 ) {
                        $san_val = sprintf( '%vd', $san_val );
                    } else {
                        $san_val = sprintf( '%*v02X', ':', $san_val );
                        $san_val =~ s/([[:xdigit:]]{2}):([[:xdigit:]]{2})/$1$2/g;
                    }
                } elsif ($type eq 'directoryName') {
                    $san_val = OpenXPKI::Crypt::DN->new( sequence => $san_val->{rdnSequence} )->get_subject();
                } elsif ($type eq 'otherName') {
                    # TODO - this needs some improvemnt to not swallow the type
                    # and support nested values
                    my $tagval = decode_tag($san_val->{value}) // encode_base64($san_val->{value}) // '<undef>';
                    $san_val = sprintf('%s:%s', $san_val->{type}, $tagval);
                    $san_val =~ s{[\x00-\x1F\x7F]}{X}g; # should not be the case but who knows
                }
                push @san_list, [ $san_type, $san_val ];
            }
        }
    }

    return \@san_list;
}

sub _get_validity {
    my $self = shift;
    my $date = shift;
    my $format = shift || '';

    if ($format eq 'epoch') {
        return $date;
    }

    $date = DateTime->from_epoch( epoch => $date);

    if (!$format) {
        return $date;
    }

    return OpenXPKI::DateTime::convert_date({
        DATE      => $date,
        OUTFORMAT => $format,
    });
}

sub _build_cert_subject_parts_hash {
    my $self = shift;
    my $hash = $self->subject_hash();

    my $sans = $self->get_subject_alt_name();
    for my $san ($sans->@*) {
        my ($type, $value) = $san->@*;
        $type = 'SAN_'.uc($type);
        $hash->{$type} = [] unless(defined $hash->{$type});
        push @{$hash->{$type}}, $value;
    }
    return $hash;
}

sub _to_db_hash {

    my $self = shift;

    my $hash = {
        cert_key => $self->get_serial(),
        identifier      => $self->get_cert_identifier(),
        data            => $self->pem(),
        subject         => $self->get_subject(),
        issuer_dn       => $self->get_issuer(),
        subject_key_identifier => $self->get_subject_key_id(),
        authority_key_identifier => $self->get_authority_key_id(),
        notafter        => $self->notafter(),
        notbefore       => $self->notbefore(),
    };
    return $hash;

}

sub _build_basic_constraints {

    my $self = shift;

    my ($ext) = grep { $_->{'extnID'} eq '2.5.29.19' }
        @{$self->_cert->{'tbsCertificate'}->{'extensions'} // []};

    my %bc = (ca => 0, critical => 0, pathlen => undef);
    return \%bc unless $ext;

    $bc{critical} = $ext->{'critical'} ? 1 : 0;

    require Convert::ASN1;
    my $asn = Convert::ASN1->new;
    $asn->prepare(q<
        BasicConstraints ::= SEQUENCE {
            cA                  BOOLEAN OPTIONAL,
            pathLenConstraint   INTEGER OPTIONAL
        }
    >) or die "ASN.1 prepare failed: " . $asn->error;
    my $decoded = $asn->decode($ext->{'extnValue'})
        or die "ASN.1 decode failed: " . $asn->error;
    $bc{ca} = ($decoded->{'cA'} ? 1 : 0) if exists $decoded->{'cA'};
    $bc{pathlen} = $decoded->{'pathLenConstraint'} if exists $decoded->{'pathLenConstraint'};
    return \%bc;
}

sub _build_authority_info {

    my $self = shift;

    my ($extvalue) = map {
        $_->{'extnID'} eq '1.3.6.1.5.5.7.1.1' ? $_->{'extnValue'} : ()
    } @{$self->_cert->{'tbsCertificate'}->{'extensions'} // []};

    return { caIssuer => [], ocsp => [] } unless $extvalue;

    require Convert::ASN1;
    my $asn = Convert::ASN1->new;
    $asn->prepare(q{
        AuthorityInfoAccessSyntax ::= SEQUENCE OF AccessDescription

        AccessDescription ::= SEQUENCE {
            accessMethod    OBJECT IDENTIFIER,
            accessLocation  GeneralName
        }

        GeneralName ::= CHOICE {
            otherName     [0]     ANY,
            rfc822Name    [1]     IA5String,
            dNSName       [2]     IA5String,
            x400Address   [3]     ANY,
            directoryName [4]     ANY,
            ediPartyName  [5]     ANY,
            uniformResourceIdentifier [6] IA5String,
            iPAddress     [7]     OCTET STRING,
            registeredID  [8]     OBJECT IDENTIFIER
        }
    }) or die "ASN.1 prepare failed: " . $asn->error;

    my $parser = $asn->find('AuthorityInfoAccessSyntax')
        or die "Cannot find AuthorityInfoAccessSyntax in ASN.1 schema";
    my $decoded = $parser->decode($extvalue) or die $parser->error;

    my %raw;
    foreach my $desc (@{$decoded}) {
        next unless $desc->{accessLocation}->{uniformResourceIdentifier};
        push @{$raw{$desc->{accessMethod}}}, $desc->{accessLocation}->{uniformResourceIdentifier};
    }

    return {
        caIssuer => $raw{'1.3.6.1.5.5.7.48.2'} // [],
        ocsp     => $raw{'1.3.6.1.5.5.7.48.1'} // [],
    };
}

__PACKAGE__->meta->make_immutable;

__END__;
