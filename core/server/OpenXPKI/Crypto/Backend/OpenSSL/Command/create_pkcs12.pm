## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs12
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## enhanced 2006 by Alexander Klink for the OpenXPKI project
## to support Cryptographic Service Provider names
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs12;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->get_tmpfile ('KEY', 'CERT', 'CHAIN', 'OUT');

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

    ## prepare data

    $self->write_file (FILENAME => $self->{KEYFILE},
                       CONTENT  => $self->{KEY},
                   FORCE    => 1);
    $self->write_file (FILENAME => $self->{CERTFILE},
                       CONTENT  => $self->{CERT},
                   FORCE    => 1);
    if (exists $self->{CHAIN} && scalar @{$self->{CHAIN}}) {
        my $chain = join("\n", @{$self->{CHAIN}});
        $self->write_file(
            FILENAME => $self->{CHAINFILE},
            CONTENT  => $chain,
            FORCE    => 1
        );
    } else {
        $self->{CHAIN} = undef;
    }

    ## build the command

    my $command  = "pkcs12 -export";
    $command .= " -engine $engine" if ($engine);
    $command .= " -inkey ".$self->{KEYFILE};
    $command .= " -in ".$self->{CERTFILE};
    $command .= " -out ".$self->{OUTFILE};

    $command .= " -keypbe ".$self->{KEY_PBE} if ($self->{KEY_PBE});
    $command .= " -certpbe ".$self->{CERT_PBE} if ($self->{CERT_PBE});

    $command .= " -name " . $self->{ALIAS} if ($self->{ALIAS});

    if (defined $self->{CSP}) {
        $command .= " -CSP " . q{"} . $self->{CSP} . q{"};
    }
    if (defined $self->{CHAIN})
    {
        $command .= " -certfile ".$self->{CHAINFILE};
    }

    $command .= " -passin env:pwd";
    $self->set_env ("pwd" => $self->{PASSWD});

    $command .= " -passout env:p12pwd";
    if ($self->{PKCS12_PASSWD} && !$self->{NOPASSWD}) {
        $self->set_env ('p12pwd' => $self->{PKCS12_PASSWD});
    } else {
        $self->set_env ('p12pwd' => '');
    }

    return [ $command ];
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

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}

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

=item * KEY_PBE, CERT_PBE, CSP (optional)

Passed as is to the openssl options with the same name.

=back

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

returns the newly created PKCS#12 container
