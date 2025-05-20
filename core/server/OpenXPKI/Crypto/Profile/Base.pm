package OpenXPKI::Crypto::Profile::Base;
use OpenXPKI;

=head1 NAME

OpenXPKI::Crypto::Profile::Base - base class for cryptographic profiles
for certificates and CRLs.

=head1 DESCRIPTION

Base class for profiles used in the CA.

=cut

# Core modules
use MIME::Base64;

# CPAN modules
use DateTime;
use Template;

# Project modules
use OpenXPKI::Crypt::X509;
use OpenXPKI::Server::Context qw( CTX );


=head1 FUNCTIONS

=head2 load_extension

Load data from the extensions section

=over

=item * PROFILE (certificates only)

Name of the profile to get the extension from.

=item * CA (crl only)

Name of the CA to get the extension from.

=item * EXT

Name of the extension to load.

=back

=cut

sub load_extension
{
    ##! 1: 'start'
    my $self  = shift;
    my $args  = shift;
    my $profile_path = $args->{PATH};
    my $ext = $args->{EXT};
    my @values  = ();

    ##! 32: Dumper ( $args )

    my $config = CTX('config');

    ##! 4: "Profile: $profile_path, Extension: $ext"
    my @basepath = split /\./, $profile_path;
    # the netscape stuff is one level down
    if ($ext =~ m{netscape_(\w+)}) {
        push @basepath, 'extensions', 'netscape', $1;
    } else {
        push @basepath, 'extensions', $ext;
    }

    ##! 16: 'path: ' . join (".", @basepath)

    ## is the extension used at all?
    if (!$config->exists(\@basepath)) {
        # Test for default settings
        $basepath[1] = 'default';
        if ($config->exists(\@basepath)) {
            ##! 16: 'Using default value for ' . $ext
        } else {
            ##! 16: "Extension $ext is not used"
            return 0;
        }
    }

    ## is this a critical extension?

    my $critical;
    if ($ext !~ m{(oid|ocsp_nocheck)}) {
        $critical = $config->get([ @basepath, 'critical' ]);
        if ($critical) {
            $critical = 'true';
        } elsif (defined $critical) {
             $critical = 'false';
        } else {
            CTX('log')->application()->warn("Critical flag is not set for $ext in profile $profile_path!");
        }
    }

    if ($ext eq "basic_constraints")
    {

        my $ca = $config->get([ @basepath, 'ca' ]) || '0';
        if ($ca !~ /\A(true|1)\z/) {
            $values[0] = ["CA", 'false'];
        } else {
            $values[0] = ["CA", 'true'];

            my $path_length = $config->get([ @basepath, 'path_length']);
            if (defined $path_length)
            {
                $values[1] = ["PATH_LENGTH", $path_length];
            }
        }

        $self->set_extension (NAME     => "basic_constraints",
                              CRITICAL => $critical,
                              VALUES   => [@values]);
    }
    elsif ($ext eq "key_usage")
    {
        my @bits = ( "digital_signature", "non_repudiation", "key_encipherment",
                     "data_encipherment", "key_agreement", "key_cert_sign",
                     "crl_sign", "encipher_only", "decipher_only" );

        foreach my $bit (@bits) {
            push @values, $bit if ($config->get([ @basepath, $bit ]));
        }

        $self->set_extension (NAME     => "key_usage",
                              CRITICAL => $critical,
                              VALUES   => [@values]);
    }
    elsif ($ext eq "extended_key_usage")
    {
        my $bits_set = $config->get_hash(\@basepath);
        ##! 16: "ext key usage bits: ". Dumper $bits_set
        my @bits = ( "client_auth", "server_auth","email_protection","code_signing","time_stamping", "ocsp_signing");

        foreach my $bit (@bits) {
            push @values, $bit if ( $bits_set->{$bit} );
        }

        # check keys of hash for numeric oids
        foreach my $oid (keys %{$bits_set}) {
            if ($oid =~ /^\d+(\.\d+)+$/) {
                push @values, $oid;
            }
        }

        if (scalar @values)
        {
            $self->set_extension (NAME     => "extended_key_usage",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "subject_key_identifier")
    {
        if ($config->get([ @basepath, 'hash']))
        {
            $self->set_extension (NAME     => "subject_key_identifier",
                                  CRITICAL => $critical,
                                  VALUES   => ["hash"]);
        }
    }
    elsif ($ext eq "authority_key_identifier")
    {

        my @bits = ( "keyid", "issuer" );
        foreach my $bit (@bits) {
            push @values, $bit if ( $config->get([ @basepath, $bit ]) );
        }
        if (scalar @values)
        {
            $self->set_extension (NAME     => "authority_key_identifier",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "issuer_alt_name")
    {
        if ($config->get([ @basepath, 'copy' ]) )
        {
            $self->set_extension (NAME     => "issuer_alt_name",
                                  CRITICAL => $critical,
                                  VALUES   => ["copy"]);
        }
    }
    elsif ($ext eq "crl_distribution_points")
    {

        my @uri = $config->get_scalar_as_list([ @basepath, 'uri' ]);
        # Parse using Template Toolkit
        @values = @{ $self->process_templates(\@uri) };

        if (scalar @values)
        {
            $self->set_extension (NAME     => "cdp",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "authority_info_access")
    {
        foreach my $bit (qw(ca_issuers ocsp)) {

            my @template_list = $config->get_scalar_as_list([ @basepath, $bit ]);
            # Parse using Template Toolkit and push result
            if (scalar @template_list) {
                push @values, [uc($bit), $self->process_templates( \@template_list ) ];
            }
        }

        if (scalar @values)
        {
            $self->set_extension (NAME     => "authority_info_access",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }
    }
    elsif ($ext eq "policy_identifier")
    {
        # OIDs only
        my @oids = $config->get_scalar_as_list([ @basepath , 'oid' ]);
        ##! 16: 'short oids ' . Dumper \@oids
        foreach my $oid (@oids) {
            next if ($oid !~ /\d+(\.\d+)+/);
            push @values, $oid;
        }


        # Support the old config format with one oid and
        # user_notice in a seperate section
        if (scalar @values == 1) {
            pop @basepath;
            my @user_notice = $config->get_scalar_as_list([ @basepath, "user_notice" ]);
            if (@user_notice) {
                $values[0] = {
                    oid => $values[0],
                    user_notice => \@user_notice
                };
            }
            push @basepath, "policy_identifier";
        }

        # check remaining keys for policy with extra sections (CPS + Notice)
        @oids = $config->get_keys(\@basepath);
        ##! 16: 'full oid sections ' . Dumper \@oids
        foreach my $name (@oids) {
            next if ($name !~/\d+(\.\d+)+/);
            my $attr = { oid => $name };
            my @cps = $config->get_scalar_as_list( [ @basepath, $name, 'cps' ] );
            if (@cps) {
                $attr->{cps} = \@cps;
            }
            my @notice = $config->get_scalar_as_list( [ @basepath, $name, 'user_notice' ] );
            if (@notice) {
                $attr->{user_notice} = \@notice;
            }
            ##! 32: 'Policy Attribute ' . Dumper $attr
            push @values, $attr;
        }

        if (scalar @values) {
            $self->set_extension (NAME     => "policy_identifier",
                                  CRITICAL => $critical,
                                  VALUES   => [@values]);
        }

    }
    elsif ($ext eq "oid")
    {

        my @oids = $config->get_keys(\@basepath);
        foreach my $name (@oids) {

            my $attr = $config->get_hash( [ @basepath, $name ] );
            ##! 32: 'oid attributes, name ' . $name. ', attr: ' . Dumper $attr

            if (!$attr->{value}) {
                next;
            }

            # OID can be either the name or given as attribute "oid"
            if ($attr->{oid}) {
                $name = $attr->{oid};
            }

            # Special case, Sequences needs to be written to a new section
            if ($attr->{encoding} eq 'SEQUENCE') {
                $self->set_oid_extension_sequence(
                    NAME => $name,
                    CRITICAL => ($attr->{critical} ? 'true' : 'false'),
                    VALUES   => $attr->{value}
                );
            } else {

                my $val = '';
                # format and encoding can be given as extra parameters but
                # finally just end up concatenated with the value
                if ($attr->{format}) {
                    $val .= $attr->{format}.':';
                }
                if ($attr->{encoding}) {
                    $val .= $attr->{encoding}.':';
                }
                $val .= $attr->{value};
                @values = ( $val );

                $self->set_extension(NAME => $name,
                    CRITICAL => ($attr->{critical} ? 'true' : 'false'),
                    VALUES   => [@values]);
            }
        }
    }
    elsif ($ext eq "ocsp_nocheck")
    {
        if ($config->get([ @basepath ]))
        {
            $self->set_extension (
                NAME => "1.3.6.1.5.5.7.48.1.5",
                CRITICAL => "false",
                VALUES   => [ "ASN1:NULL" ],
            );
        }
    }
    elsif ($ext eq "netscape_comment")
    {
        my $comment = $config->get([ @basepath , 'text' ]);
        if ($comment)
        {
            $self->set_extension (NAME     => "netscape_comment",
                              CRITICAL => $critical,
                              VALUES   => [ $comment ]);
        }
    }
    elsif ($ext eq "netscape_certificate_type")
    {
        my @bits = ( "ssl_client", "smime_client", "object_signing",
                     "ssl_client_ca", "smime_client_ca", "object_signing_ca", "ssl_server", "reserved" );

        foreach my $bit (@bits) {
            push @values, $bit if ( $config->get([ @basepath , $bit ]) );
        }

        if (scalar @values) {
            $self->set_extension (NAME     => "netscape_certificate_type",
              CRITICAL => $critical,
              VALUES   => [@values]);
        }

    }
    elsif ($ext eq "netscape_cdp")
    {

        my $cdp = $config->get([ @basepath , 'uri' ]);
        if ($cdp) {
            $self->set_extension (NAME     => "netscape_cdp",
                  CRITICAL => $critical,
                  VALUES   => [$cdp]);
        }

        my $ca_cdp = $config->get([ @basepath , 'ca_uri' ]);
        if ($ca_cdp) {
            $self->set_extension (NAME     => "netscape_ca_cdp",
                              CRITICAL => $critical,
                              VALUES   => [$ca_cdp]);
        }
    }
    else
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_LOAD_EXTENSION_UNKNOWN_NAME",
            params  => {NAME => $ext, PATH =>  join(".", @basepath) }
        );
    }

    return 1;
}

sub set_extension
{
    ##! 1: 'start'
    my $self = shift;
    my $keys = { @_ };
    my $name     = $keys->{NAME};
    my $critical = $keys->{CRITICAL};
    my $value    = $keys->{VALUES};
    my $force    = $keys->{FORCE};


    if (! defined $name) {
    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_SET_EXTENSION_NAME_NOT_SPECIFIED",
        );
    }

    if ($self->{PROFILE}->{EXTENSIONS}->{$name}) {
        if (!$force) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_SET_EXTENSION_ALREADY_SET",
                params => { NAME => $name }
            );
        }
        $self->{PROFILE}->{EXTENSIONS}->{$name} = {};
    }

    if (! defined $value) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_SET_EXTENSION_VALUE_NOT_SPECIFIED",
        );
    }
    if (! defined $critical) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_SET_EXTENSION_CRITICALITY_NOT_SPECIFIED",
        params => {
        NAME => $name,
        VALUE => $value,
        });
    }
    if ($critical !~ m{ \A (?:true|false) }xms) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_SET_EXTENSION_INVALID_CRITICALITY",
        params => {
        NAME => $name,
        VALUE => $value,
        CRITICALITY => $critical,
        });
    }

    ##! 16: 'name: ' . $name
    ##! 16: 'critical: ' . $critical
    ##! 16: 'value: ' . Dumper ( $value )

    $critical = 0 if ($critical eq "false");
    $critical = 1 if ($critical eq "true");
    $self->{PROFILE}->{EXTENSIONS}->{$name}->{CRITICAL} = $critical;


    if (!ref $value) {
        $self->{PROFILE}->{EXTENSIONS}->{$name}->{VALUE} = [ $value ];
    } else {
        ## copy by value (normal array)
        $self->{PROFILE}->{EXTENSIONS}->{$name}->{VALUE} = [ @{$value} ];
    }

    return 1;
}

=head2 generate_oid_extension_section

Wrapper around set_extension to prepare oid extensions with sequence

=cut

sub set_oid_extension_sequence {

    my $self = shift;
    my $keys = { @_ };
    my $name     = $keys->{NAME};
    my $critical = $keys->{CRITICAL};
    my $value    = $keys->{VALUES};

    my $section = 'oid_section_'.$name;
    $section =~ s/\./_/g;
    my @values = ( 'ASN1:SEQUENCE:'.$section, "[ $section ]" );
    my @section = split /\r?\n/, $value;
    push @values, @section;

    # incoming value for critical should already be "true" or "false"
    return $self->set_extension(NAME => $name,
        CRITICAL => $critical,
        VALUES   => [@values]);

}

sub is_critical_extension
{
    my $self = shift;
    my $ext  = shift;

    if (not exists $self->{PROFILE}->{EXTENSIONS}->{$ext})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_IS_CIRITICAL_EXTENSION_NOT_FOUND");
    }

    return $self->{PROFILE}->{EXTENSIONS}->{$ext}->{CRITICAL};
}

sub get_extension
{
    my $self = shift;
    my $ext  = shift;

    if (not exists $self->{PROFILE}->{EXTENSIONS}->{$ext})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_GET_EXTENSION_NOT_FOUND",
            params  => {
                "EXTENSION" => $ext,
            },
        );
    }

    if (not defined $self->{PROFILE}->{EXTENSIONS}->{$ext}->{VALUE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_GET_EXTENSION_NO_VALUE",
            params  => {
                "EXTENSION" => $ext,
            },
        );
    }

    return $self->{PROFILE}->{EXTENSIONS}->{$ext}->{VALUE};

}


sub has_extension
{
    my $self = shift;
    my $ext  = shift;

    return ((exists $self->{PROFILE}->{EXTENSIONS}->{$ext})
        && (defined $self->{PROFILE}->{EXTENSIONS}->{$ext}->{VALUE}));

}

sub set_padding {
    my $self = shift;
    $self->{PROFILE}->{PADDING} = shift;
    return 1;
}

sub get_padding {
    my $self = shift;
    return $self->{PROFILE}->{PADDING};
}

sub set_serial
{
    my $self = shift;
    $self->{PROFILE}->{SERIAL} = shift;
    return 1;
}

sub get_serial
{
    my $self = shift;
    return $self->{PROFILE}->{SERIAL};
}

sub get_oid_extensions
{
    my $self = shift;
    return grep /\d+\./, keys %{$self->{PROFILE}->{EXTENSIONS}};
}

sub get_named_extensions
{
    my $self = shift;
    return grep /[^(\d+\.)]/, keys %{$self->{PROFILE}->{EXTENSIONS}};
}

# string_mask has no effect in CRL but is required to properly build the config
sub get_string_mask
{
    my $self = shift;
    return $self->{PROFILE}->{STRING_MASK} || 'utf8only';
}

=head2 create_random_serial

Generate a random serial number (ID) and return it as a L<Math::BigInt> object.

B<Parameters>

=over

=item PREFIX - High order bits to prepend to the generated serial number (optional)

=item RANDOM_LENGTH - The desired byte length of the random part

=back

=cut
sub create_random_serial {
    my ($self, %args) = @_;

    OpenXPKI::Exception->throw(message => 'Mandatory parameter RANDOM_LENGTH missing')
        unless defined $args{'RANDOM_LENGTH'};

    my $serial = Math::BigInt->new( $args{'PREFIX'} // 0);
    my $rand_length = $args{'RANDOM_LENGTH'};
    ##! 16: "create_random_serial({ RANDOM_LENGTH => $rand_length, PREFIX => " . $serial->as_hex . " })"

    if ($rand_length > 0) {
        my $rand_hex = CTX('api2')->get_random(
            length => $rand_length,
            format => 'hex',
        );

        ##! 16: 'random part: ' . $rand_hex
        # left shift the existing serial by the size of the random part and
        # add it to the right
        $serial->blsft($rand_length * 8);
        ##! 16: 'bit shifted serial: ' . $serial->as_hex
        $serial->bior(Math::BigInt->new('0x' . $rand_hex));
    }
    ##! 16: 'returning: ' . $serial->as_hex
    return $serial->bstr; # return serial as "decimal notation, possibly zero padded"
}

=head2 process_templates

Helper method to parse profile items through template toolkit.
Expects an array of strings containing one TT Template per line.
Available variables for substitution are

=over

=item ISSUER.x Hash with the subject parts of the issuing certificate.

Note that each key is an array itself, even if there is only a single value in it.
Therefore you need to write e.g. ISSUER.OU.0 for the (first) OU entry. Its wise
to do urlescaping on the output, e.g. [- ISSUER.OU.0 | uri -].

The hash also has ISSUER.DN set with the full dn.

=item CAALIAS Hash holding information about the used ca token.

Offers the keys ALIAS, GROUP, GENERATION as given in the alias table.

=item PKI_REALM

The internal name of the realm (e.g. "democa").

=back

=cut

sub process_templates {

    my $self = shift;
    my $values = shift;

    # Add ability to use template toolkit - check if there are tags inside

    ##! 32: ' Test for TT ' . Dumper ( $values )
    if (! scalar(grep /\[.*\]/, @$values) ) {
        return $values;
    }

    ##! 16: 'Tags found - init TT'
    my $tt = Template->new();


    if (not $self->{CACERTIFICATE}) {
        $self->{CACERTIFICATE} = CTX('api2')->get_certificate_for_alias( 'alias' => $self->{CA} );
    }

    my $ca_cert;
    if ($self->{CACERTIFICATE}->{data}) {
        $ca_cert = $self->{CACERTIFICATE}->{data};
    # old format
    } elsif ($self->{CACERTIFICATE}->{DATA}) {
        $ca_cert = $self->{CACERTIFICATE}->{DATA};
    } else {
        OpenXPKI::Exception->throw(
            message => 'Unable to load CA Certificate',
        );
    }

    my $x509 = OpenXPKI::Crypt::X509->new( $ca_cert );

    # Get Issuer Info from selected ca
    my $issuer_info = $x509->subject_hash();
    $issuer_info->{DN} = $x509->get_subject();

    # Split alias into generation and group name
    $self->{CA} =~ /^(.*)-(\d+)$/;
    my $group = $1;
    my $generation = $2;

    my %template_vars = (
        'ISSUER' => $issuer_info,
        # TODO - deprecate the old structure
        'CAALIAS' => {
            'ALIAS' => $self->{CA},
            'GROUP' => $group,
            'GENERATION' => $generation,
        },
        # We use the same template for key name generation but do not
        # have the CAALIAS prefix there. To make the consistent we add
        # this also on top level now and deprecate the old format
        'ALIAS' => $self->{CA},
        'GROUP' => $group,
        'GENERATION' => $generation,
        'PKI_REALM' => CTX('api2')->get_pki_realm(),
    );
    ##! 32: ' Template Vars ' . Dumper ( %template_vars )

    my @newvalues;
    while (my $template = shift @$values) {
        if ($template =~ /\[.+\]/) {
            my $output;
            #$template = '[% TAGS [- -] -%]' .  $template;
            if (!$tt->process(\$template, \%template_vars, \$output)) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_CRYPTO_PROFILE_BASE_ERROR_PARSING_TEMPLATE',
                    params => {
                        'TEMPLATE' => $template,
                        'ERROR' => $tt->error()
                    }
                );
            }

            ##! 32: ' Tags found - ' . $template . ' -> '. $output
            if($output) {
                push @newvalues, $output;
            }
        } else {
            push @newvalues, $template;
        }
    }

    ##! 64: ' Processed CRL DP ' . Dumper ( @newvalues )
    return \@newvalues;
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    return if ($AUTOLOAD =~ m{ \A .*::DESTROY \z}xms);
    return "" if ($AUTOLOAD =~ s/^.*:get_//);
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_PROFILE_BASE_AUTOLOAD_ILLEGAL_FUNCTION",
        params  => {"FUNCTION" => $AUTOLOAD});
}

1;
__END__
