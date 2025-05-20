package OpenXPKI::Crypt::X509;
use OpenXPKI -class;

use OpenXPKI::DN;
use Digest::SHA qw(sha1_base64 sha1_hex);
use OpenXPKI::DateTime;
use MIME::Base64;
use Crypt::X509 0.53;

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
BasicContraints "cA" set (critical), false otherwise.

=cut

sub is_ca {

    my $self = shift;

    my $keyUsage = $self->_cert->KeyUsage();
    return 0 unless (grep { 'keyCertSign' } @{$keyUsage});

    my $constraint = $self->_cert->BasicConstraints();
    return 1 if (ref $constraint eq 'ARRAY' &&
        @{$constraint} == 2 &&
        $constraint->[0] eq 'critical' &&
        $constraint->[1] eq 'cA = 1');

    return 0;
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

__PACKAGE__->meta->make_immutable;

__END__;
