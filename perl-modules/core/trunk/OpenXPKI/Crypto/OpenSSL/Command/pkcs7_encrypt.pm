## OpenXPKI::Crypto::OpenSSL::Command::pkcs7_encrypt
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::pkcs7_encrypt;

use base qw(OpenXPKI::Crypto::OpenSSL::Command);

=head1 Parameters

=over

=item * CONTENT

=item * USE_ENGINE (optional)

=item * CERT (optional)

=item * ENC_ALG (optional)

=back

=cut

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->{CONTENTFILE} = $self->{TMP}."/${$}_content.pem";
    $self->{CLEANUP}->{FILE}->{CONTENT} = $self->{CONTENTFILE};
    $self->{OUTFILE} = $self->{TMP}."/${$}_pkcs7.pem";
    $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};

    my $engine = "";
       $engine = $self->{ENGINE}->get_engine()
           if ($self->{USE_ENGINE} and $self->{ENGINE}->get_engine());
    $self->{ENC_ALG}  = "aes256" if (not exists $self->{ENC_ALG});

    if ($self->{CERT})
    {
        $self->{CERTFILE} = $self->{TMP}."/${$}_cert.pem";
        $self->{CLEANUP}->{FILE}->{CERT} = $self->{CERTFILE};
        return undef
            if (not $self->write_file (FILENAME => $self->{CERTFILE},
                                       CONTENT  => $self->{CERT}));
    } else {
        $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
    }

    ## check parameters

    if (not $self->{CONTENT})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_ENCRYPT_MISSING_CONTENT");
        return undef;
    }
    if (not $self->{CERT})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_ENCRYPT_MISSING_CERT");
        return undef;
    }
    if ($self->{ENC_ALG} ne "aes256" and
        $self->{ENC_ALG} ne "aes192" and
        $self->{ENC_ALG} ne "aes128" and
        $self->{ENC_ALG} ne "idea" and
        $self->{ENC_ALG} ne "des3" and
        $self->{ENC_ALG} ne "des")
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_ENCRYPT_WRONG_ENC_ALG");
        return undef;
    }

    ## prepare data

    return undef
        if (not $self->write_file (FILENAME => $self->{CONTENTFILE},
                                   CONTENT  => $self->{CONTENT}));

    ## build the command

    my $command  = "smime -encrypt";
    $command .= " -engine $engine" if ($engine);
    $command .= " -in ".$self->{CONTENTFILE};
    $command .= " -out ".$self->{OUTFILE};
    $command .= " -outform PEM";
    $command .= " -".$self->{ENC_ALG};
    $command .= " ".$self->{CERTFILE};

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
