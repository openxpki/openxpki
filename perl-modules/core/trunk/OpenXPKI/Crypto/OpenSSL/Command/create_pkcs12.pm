## OpenXPKI::Crypto::OpenSSL::Command::create_pkcs12
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::create_pkcs12;

use base qw(OpenXPKI::Crypto::OpenSSL::Command);

=head1 Parameters

Only the engine is optional all other parameters must be present.
This function was only designed for normal certificates. They are
not designed for the tokens themselves.

=over

=item * KEY

=item * USE_ENGINE (optional)

=item * PASSWD

=item * CERT

=item * PKCS12_PASSWD (optional)

If you do not specify this option then we use PASSWD to encrypt the new
PKCS#12 file.

=item * ENC_ALG (optional)

=item * CHAIN (optional)

=back

=cut

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->{KEYFILE} = $self->{TMP}."/${$}_key.pem";
    $self->{CLEANUP}->{FILE}->{KEY} = $self->{KEYFILE};
    $self->{CERTFILE} = $self->{TMP}."/${$}_cert.pem";
    $self->{CLEANUP}->{FILE}->{CERT} = $self->{CERTFILE};
    $self->{OUTFILE} = $self->{TMP}."/${$}_pkcs12.pem";
    $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};

    my $engine = "";
       $engine = $self->{ENGINE}->get_engine()
           if ($self->{USE_ENGINE} and $self->{ENGINE}->get_engine());
    $self->{PKCS12_PASSWD} = $self->{PASSWD}
        if (not exists $self->{PKCS12_PASSWD});
    $self->{ENC_ALG} = "aes256" if (not exists $self->{ENC_ALG});

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
    if ($self->{ENC_ALG} ne "aes256" and
        $self->{ENC_ALG} ne "aes192" and
        $self->{ENC_ALG} ne "aes128" and
        $self->{ENC_ALG} ne "idea" and
        $self->{ENC_ALG} ne "des3" and
        $self->{ENC_ALG} ne "des")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_RSA_WRONG_ENC_ALG");
    }

    ## prepare data

    $self->write_file (FILENAME => $self->{KEYFILE},
                       CONTENT  => $self->{KEY});
    $self->write_file (FILENAME => $self->{CERTFILE},
                       CONTENT  => $self->{CERT});

    ## build the command

    my $command  = "pkcs12 -export";
    $command .= " -engine $engine" if ($engine);
    $command .= " -inkey ".$self->{KEYFILE};
    $command .= " -in ".$self->{CERTFILE};
    $command .= " -out ".$self->{OUTFILE};
    $command .= " -".$self->{ENC_ALG};
    $command .= " -certfile ".$self->{CHAIN} if ($self->{CHAIN});

    $command .= " -passin env:pwd";
    $ENV{'pwd'} = $self->{PASSWD};
    $self->{CLEANUP}->{ENV}->{PWD} = "pwd";

    $command .= " -passout env:p12pwd";
    $ENV{'p12pwd'} = $self->{PKCS12_PASSWD};
    $self->{CLEANUP}->{ENV}->{PWD} = "p12pwd";

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
    return 0 if (exists $self->{CLEANUP}->{ENV}->{PWD});
    return 1;
}

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}

1;
