package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs12;
use OpenXPKI;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters
    my $engine = "";
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $engine = $self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            (($engine_usage =~ m{ ALWAYS }xms) or
             ($engine_usage =~ m{ PRIV_KEY_OPS }xms)));

    $self->{PKCS12_PASSWD} = $self->{PASSWD}
        if (not exists $self->{PKCS12_PASSWD});


    ## check parameters

    if (not $self->{KEY})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS12_MISSING_KEY");
    }
    if (not $self->{CERT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS12_MISSING_CERT");
    }
    if (not exists $self->{PASSWD})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS12_MISSING_PASSWD");
    }
    if (not length ($self->{PASSWD}))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS12_EMPTY_PASSWD");
    }

    if (length ($self->{PKCS12_PASSWD}) < 4)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS12_PASSWD_TOO_SHORT");
    }

    if (exists $self->{CSP}) {
        # input validation, as this will be passed on to the
        # command, i.e. a shell
        # todo: Spaces are not working due to Proc::SafeExec, see #393
        if ($self->{CSP} !~ m{ \A [ \w \- \. : ]* \z }xms) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_BACKEND_OPENSSL_COMMAND_CREATE_PKCS12_CSP_IS_NOT_ALPHANUMERIC',
                params => {
                    CSP => $self->{CSP},
                },
            );
        }
    }

    if ($self->{ALIAS}) {
        # input validation, as this will be passed on to the
        # command, i.e. a shell
        if ($self->{ALIAS} !~ m{ \A [ \w \- \. : ]* \z }xms) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_BACKEND_OPENSSL_COMMAND_CREATE_PKCS12_ALIAS_NON_WORD_CHARACTERS',
                params => {
                    ALIAS => $self->{ALIAS},
                },
            );
        }
    }

    OpenXPKI::Exception->throw(
        message => 'Invalid value for KEY_PBE given to create_pkcs12 command',
        params => { KEY_PBE => $self->{KEY_PBE} },
    ) if ($self->{KEY_PBE} && $self->{KEY_PBE} !~ m{\A([A-Z0-9-]+)\z});

    OpenXPKI::Exception->throw(
        message => 'Invalid value for CERT_PBE given to create_pkcs12 command',
        params => { CERT_PBE => $self->{CERT_PBE} },
    ) if ($self->{CERT_PBE} && $self->{CERT_PBE} !~ m{\A([A-Z0-9-]+)\z});

    OpenXPKI::Exception->throw(
        message => 'Invalid value for MACALG given to create_pkcs12 command',
        params => { MACALG => $self->{MACALG} },
    ) if ($self->{MACALG} && $self->{MACALG} !~ m{\A([a-z0-9]+)\z});

    ## build the command
    my @command = ('pkcs12','-export');
    # optional engine use
    push @command, ('-engine',$engine) if ($engine);

    # mandatory arguments
    push @command, ('-inkey', $self->write_temp_file( $self->{KEY} )) ;
    push @command, ('-in', $self->write_temp_file( $self->{CERT} ));
    push @command, ('-out', $self->get_outfile());

    # extra key specs
    push @command, ('-keypbe', $self->{KEY_PBE}) if ($self->{KEY_PBE});
    push @command, ('-certpbe', $self->{CERT_PBE}) if ($self->{CERT_PBE});
    push @command, ('-macalg', $self->{MACALG}) if ($self->{MACALG});

    # the legacy flag is only available in openssl 1.1!
    push @command, ('-legacy') if ($self->{LEGACY});

    # set an alias name
    push @command, ('-name', $self->{ALIAS}) if ($self->{ALIAS});

    # csp name
    if (defined $self->{CSP}) {
        push @command, ('-CSP', q{"} . $self->{CSP} . q{"} );
    }

    if (exists $self->{CHAIN} && scalar @{$self->{CHAIN}}) {
        my $chain = join("\n", @{$self->{CHAIN}});
        push @command, ('-certfile', $self->write_temp_file( $chain ) );
    }

    push @command, ('-passin','env:pwd');
    $self->set_env ("pwd" => $self->{PASSWD});

    push @command, ('-passout','env:p12pwd');
    if ($self->{PKCS12_PASSWD} && !$self->{NOPASSWD}) {
        $self->set_env ('p12pwd' => $self->{PKCS12_PASSWD});
    } else {
        $self->set_env ('p12pwd' => '');
    }

    return [ \@command ];
}

sub hide_output
{
    return 0;
}

## please notice that key_usage means usage of the engine's key
sub key_usage
{
    my $self = shift;
    return 0;
}

#get_result moved to base class

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs12

=head1 Functions

=head2 get_command

Only the engine is optional all other parameters must be present.
This function was only designed for normal certificates. They are
not designed for the tokens themselves.

=over

=item * KEY

=item * ENGINE_USAGE

=item * PASSWD

=item * CERT

=item * PKCS12_PASSWD (optional)

If you do not specify this option then we use PASSWD to encrypt the new
PKCS#12 file.  To export the key without password, you must explicitly
set NOPASSWD to 1.

=item * NOPASSWD (optional)

=item * KEY_PBE, CERT_PBE, CSP, MACALG (optional)

Passed as is to the openssl options with the same name.

=item * LEGACY

If true, append the I<legacy> flag to the command (OpenSSL 1.1 only)

=back

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

returns the newly created PKCS#12 container
