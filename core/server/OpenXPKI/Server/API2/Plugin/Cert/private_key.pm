package OpenXPKI::Server::API2::Plugin::Cert::private_key;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::private_key

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_private_key_for_cert

returns an ecrypted private key for a certificate if the private
key was generated on the CA during the certificate request process.

Parameters are the same as for I<convert_private_key> except that
I<private_key> must not be passed but is read from the datapool and
I<cert_identifier> is mandatory.

=cut

command "get_private_key_for_cert" => {
    identifier => { isa => 'Base64', required => 1, },
    format     => { isa => 'Str', matching => qr{ \A ( PKCS8_(PEM|DER) | OPENSSL_(PRIVKEY|RSA) | PKCS12(_LEGACY(_NOFLAG)?|_VANILLA)? | JAVA_KEYSTORE ) \z }xms, required => 1, },
    password   => { isa => 'Str', required => 1, },
    passout    => { isa => 'Str', },
    nopassword => { isa => 'Bool', default => 0, },
    keeproot   => { isa => 'Bool', default => 0, },
    alias      => { isa => 'AlphaPunct', },
    csp        => { isa => 'AlphaPunct', },
} => sub {
    my ($self, $params) = @_;

    my $identifier = $params->identifier;
    my $nopassword = $params->nopassword;

    if ($nopassword) {
        CTX('log')->audit('key')->warn("private key export without password", { certid => $identifier });
    } else {
        CTX('log')->audit('key')->info("private key export", { certid => $identifier });
    }

    my $private_key = $self->get_private_key_from_db($identifier)
        or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_PRIVATE_KEY_NOT_FOUND_IN_DB',
            params => { 'IDENTIFIER' => $identifier, },
        );

    $params->{private_key} = $private_key;

    return $self->api->convert_private_key(%$params);

};


=head2 convert_private_key

expects a private key and converts it into another format. If a bundle
with certificates is requested (PKCS12, JKS), the certificate to use as the
end entity certificate must be given via I<identifier> or as first element of
I<chain>.

=over

=item * format - the output format

=over

=item PKCS8_PEM (PKCS#8 in PEM format)

=item PKCS8_DER (PKCS#8 in DER format)

=item PKCS12 (PKCS#12 in DER format)

Enforces AES-256-CBC for key and certificate encryption, this is the
default format in OpenSSL 3.0 and should work on most recent systems.

=item PKCS12_LEGACY (PKCS#12 in DER format)

Enforces PBE-SHA1-3DES (key) and PBE-SHA1-RC2-40 (certificate). Should
work on most aged systems but does NOT work on modern systems where RC2
is deprecated / prevented due to security reasons.

Passes the C<legacy> flag to openssl which works only on OpenSSL 3.x.

=item PKCS12_LEGACY_NOFLAG

Same settings above but does NOT set the C<legacy> flag

Works only on OpenSSL 1.x.

=item PKCS12_VANILLA (PKCS#12 in DER format)

Do not pass any options to OpenSSL and use the default format. This is
considered dangerous as changes in the system environment might affect
the format of your generated containers.

=item OPENSSL_PRIVKEY (OpenSSL native key format in PEM)

=item OPENSSL_RSA (OpenSSL RSA with DEK-Info Header)

=item JAVA_KEYSTORE (JKS including chain).

=back

=item * password - the private key password

Password that was used when the key was generated.

=item * passout - the password for the exported key, default is PASSWORD

The password to encrypt the exported key with, if empty the input password
is used.

This option is only supported with format OPENSSL_PRIVKEY, PKCS12 and JKS!

=item * nopasswd

If set to a true value, the B<key is exported without a password!>.
You must also set passout to the empty string.

=item * identifier

the identifier of the certificate to merge into the export file.
The output file will contain also certificates of the chain, with or
without root weather I<keeproot> is set.
Only used with JKS or PKCS12 export format.

=item * keeproot

Boolean, when set the root certifcate is included in the keystore.
Only used when identifier is set to export PKCS12 or Java Keystore.

=item * chain

A PEM encoded list of certificates to be merged into the output file.
Only used with JKS or PKCS12 export format, content is used "as is" and
concatenated to the chain retrieved from I<identifier>/I<keeproot>.

If I<identifier> is not set, the first certificate of the chain must match
the private key.

=item * alias

String to set as alias for the key/certificate for JKS or PKCS12.

=item * csp

String, write name as a Microsoft CSP name (PKCS12 only)


=back

If the input password does not decrypt the private key, an exception is thrown.

=cut

command "convert_private_key" => {

    private_key => { isa => 'PEMPKey', required => 1 },
    format     => { isa => 'Str', matching => qr{ \A ( PKCS8_(PEM|DER) | OPENSSL_(PRIVKEY|RSA) | PKCS12(_LEGACY|_LEGACY_NOFLAG|_VANILLA)? | JAVA_KEYSTORE ) \z }xms, required => 1, },
    password   => { isa => 'Str', required => 1, },
    passout    => { isa => 'Str', },
    nopassword => { isa => 'Bool', default => 0, },
    identifier => { isa => 'Base64' },
    chain      => { isa => 'ArrayRefOrPEMCertChain', coerce => 1, },
    keeproot   => { isa => 'Bool', default => 0, },
    alias      => { isa => 'AlphaPunct', },
    csp        => { isa => 'AlphaPunct', },
} => sub {
    my ($self, $params) = @_;

    my $identifier = $params->identifier || '';
    my $format     = $params->format;
    my $password   = $params->password;
    my $pass_out   = $params->passout;
    my $nopassword = $params->nopassword;
    my $private_key = $params->private_key;

    if ($nopassword and (!defined $pass_out or $pass_out ne '')) {
        OpenXPKI::Exception->throw(
            message => "Parameter 'passout' must be set to empty string if 'nopassword' is given"
        );
    }

    if ($nopassword) {
        CTX('log')->audit('key')->warn("private key export without password");
    }

    ##! 4: 'identifier: ' . $identifier
    ##! 4: 'format: ' . $format
    ##! 16: 'pkey ' . $private_key

    # NB: The key in the database is in native openssl format
    my $command_hashref;

    if ( $format =~ /PKCS8_(PEM|DER)/ ) {
        $format = $1;
        $command_hashref = {
            PASSWD  => $password,
            DATA    => $private_key,
            COMMAND => 'convert_pkcs8',
            OUT     => $format,
            REVERSE => 1
        };

        if ($nopassword) {
            $command_hashref->{NOPASSWD} = 1;
        }
        elsif ($pass_out) {
            $command_hashref->{OUT_PASSWD} = $pass_out;
        }
    }
    elsif ( $format =~ /OPENSSL_(PRIVKEY|RSA)/ ) {

        # we just need to spit out the blob from the database but we need to check
        # if the password matches, so we do a 1:1 conversion
        $command_hashref = {
            PASSWD  => $password,
            DATA    => $private_key,
            COMMAND => 'convert_pkey',
        };

        if ($format eq 'OPENSSL_RSA') {
            $command_hashref->{KEYTYPE} = 'rsa';
        }

        if ($nopassword) {
            $command_hashref->{NOPASSWD} = 1;
        }
        elsif ($pass_out) {
            $command_hashref->{OUT_PASSWD} = $pass_out;
        }

    }
    elsif ( $format =~ m{\A(PKCS12|JAVA_KEYSTORE)} ) {

        my @chain;

        if ($identifier) {
            ##! 16: 'identifier: ' . $identifier
            @chain = $self->get_chain_certificates({
                'KEEPROOT'   => $params->keeproot,
                'IDENTIFIER' => $identifier,
                'FORMAT'     => 'PEM',
            });
        }

        if ($params->has_chain) {
            push @chain, @{$params->chain};
        }

        ##! 16: 'chain: ' . Dumper \@chain
        OpenXPKI::Exception->throw(
            message => 'private key export missing certificates',
            params => { 'FORMAT' =>  $format },
        ) unless (scalar @chain);

        # the first one is the entity certificate
        my $certificate = shift @chain;

        $command_hashref = {
            COMMAND => 'create_pkcs12',
            PASSWD  => $password,
            KEY     => $private_key,
            CERT    => $certificate,
            CHAIN   => \@chain,
        };

        # newer openssl versions use other default algorithms
        # we try to add suitable defaults independently from the used
        # openssl backend, the chosen ones are a tradeoff between
        # compatibility and security
        if ($format eq 'PKCS12') {
            $command_hashref->{KEY_PBE} = 'AES-256-CBC';
            $command_hashref->{CERT_PBE} = 'AES-256-CBC';

        # Accept PKCS12_LEGACY and PKCS12_LEGACY_NOFLAG
        } elsif ( $format =~ m{\APKCS12_LEGACY} ) {
            $command_hashref->{KEY_PBE} = 'PBE-SHA1-3DES';
            $command_hashref->{CERT_PBE} = 'PBE-SHA1-RC2-40';
            # openssl 1.0 which does not support the -legacy flag
            $command_hashref->{LEGACY} = 1 unless($format eq 'PKCS12_LEGACY_NOFLAG');
        } # anything else is JavaKS and we use the system defaults

        if ($nopassword) {
            $command_hashref->{NOPASSWD} = 1;
        }
        elsif ($pass_out) {
            $command_hashref->{PKCS12_PASSWD} = $pass_out;
            # set password for JKS export
            $password = $pass_out;
        }

        if ($params->has_csp) {
            $command_hashref->{CSP} = $params->csp;
        }

        if ($params->has_alias) {
            $command_hashref->{ALIAS} = $params->alias;
        }
        elsif ( $format eq 'JAVA_KEYSTORE' ) {
            # Java Keystore only: if no alias is specified, set to 'key'
            $command_hashref->{ALIAS} = 'key';
        }

    }

    my $result;
    eval {
        $result = $self->api->get_default_token()->command($command_hashref);
    };
    if (!$result) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_UNABLE_EXPORT_KEY',
            params => { 'IDENTIFIER' => $identifier, ERROR => $? },
        );
    }

    if ( $format eq 'JAVA_KEYSTORE' ) {
        my $token = CTX('crypto_layer')->get_system_token({ TYPE => 'javaks' });

        my $pkcs12 = $result;
        $result = $token->command({
            COMMAND      => 'create_keystore',
            PKCS12       => $pkcs12,
            PASSWD       => $password,
            OUT_PASSWD   => $password,
        });
    }

    return $result;
};

=head2 private_key_exists_for_cert

Checks whether a corresponding CA-generated private key exists for
the given certificate identifier (named parameter IDENTIFIER).
Returns true if there is a private key, false otherwise.

=cut
command "private_key_exists_for_cert" => {
    identifier => { isa => 'Base64', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $privkey = $self->get_private_key_from_db($params->identifier, 1);
    return ( defined $privkey );
};



=head1 METHODS

=head2 get_private_key_from_db

Gets a private key from the database for a given certificate
identifier by looking up the CSR serial of the certificate and
extracting the private_key from the datapool. Returns undef if
no key is available.

=cut

sub get_private_key_from_db {

    my ($self, $cert_identifier, $check_only) = @_;

    my $datapool = $self->api->get_data_pool_entry(
        namespace =>  'certificate.privatekey',
        key       =>  $cert_identifier,
        decrypt   =>  not $check_only,
    );

    # we also use the option to store the private key using the key identifier
    # instead of the certificate identifier. We leave it to the workflows to
    # take care that the mapping is unique, as the datapool has a unique index
    # on the relevant colums there is no risk that it breaks at this stage

    if (!$datapool) {

        ##! 2: "Fetching certificate from database"
        my $cert = CTX('dbi')->select_one(
            columns => [ 'subject_key_identifier' ],
            from => 'certificate',
            where => { 'identifier' => $cert_identifier },
        );

        $datapool = $self->api->get_data_pool_entry(
            namespace =>  'certificate.privatekey',
            key       =>  $cert->{subject_key_identifier},
            decrypt   =>  not $check_only,
        );

    }

    if ($datapool) {
        return $datapool->{value};
    }
    else {
        return;
    }
}

sub get_chain_certificates {
    my ($self, $args) = @_;
    ##! 4: Dumper $args
    my $id = $args->{IDENTIFIER};
    my $format = $args->{FORMAT};

    my $chain_ref = $self->api->get_chain(start_with => $id, format => $format);

    my @chain = @{ $chain_ref->{certificates} };
    ##! 16: 'Chain ' . Dumper $chain_ref

    # pop off root certificates
    if ( $chain_ref->{complete} and scalar @chain > 1 and !$args->{KEEPROOT} ) {
        pop @chain;    # we don't need the first element
    }
    ##! 1: 'end'
    return @chain;
}

__PACKAGE__->meta->make_immutable;
