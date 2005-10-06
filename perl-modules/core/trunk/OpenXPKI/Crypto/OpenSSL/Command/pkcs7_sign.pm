## OpenXPKI::Crypto::OpenSSL::Command::pkcs7_sign
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::pkcs7_sign;

use OpenXPKI::Crypto::OpenSSL::Command;
use vars qw(@ISA);
@ISA = qw(OpenXPKI::Crypto::OpenSSL::Command);

=head1 Parameters

If you want to create a signature with the used engine/token then you have
only to specify the CONTENT.

If you want to create a normal signature then you must specify at minimum
a CERT, a KEY and a PASSWD. If you want to use the engine then you must use
USE_ENGINE too.

=over

=item * CONTENT

=item * USE_ENGINE (optional)

=item * CERT

=item * KEY

=item * PASSWD

=item * ENC_ALG (optional)

=item * DETACH (strip off the content from the resulting PKCS#7 structure)

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

    $self->{ENC_ALG} = "aes256" if (not exists $self->{ENC_ALG});

    my ($engine, $passwd, $keyform);
    if ($self->{PASSWD} or $self->{KEY})
    {
        ## external signature

        # check minimum requirements
        if (not exists $self->{PASSWD})
        {
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_PASSWD");
            return undef;
        }
        if (not exists $self->{KEY})
        {
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_KEY");
            return undef;
        }
        if (not exists $self->{CERT})
        {
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_CERT");
            return undef;
        }

        # prepare parameters

        $passwd = $self->{PASSWD};
        $engine = $self->{ENGINE}->get_engine() if ($self->{USE_ENGINE});

        $self->{KEYFILE} = $self->{TMP}."/${$}_key.pem";
        $self->{CLEANUP}->{FILE}->{KEY} = $self->{KEYFILE};
        return undef
            if (not $self->write_file (FILENAME => $self->{KEYFILE},
                                       CONTENT  => $self->{KEY}));

        $self->{CERTFILE} = $self->{TMP}."/${$}_cert.pem";
        $self->{CLEANUP}->{FILE}->{CERT} = $self->{CERTFILE};
        return undef
            if (not $self->write_file (FILENAME => $self->{CERTFILE},
                                       CONTENT  => $self->{CERT}));
    } else {
        ## token signature
        $engine  = $self->{ENGINE}->get_engine();
        $keyform = $self->{ENGINE}->get_keyform();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
        $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
    }

    ## check parameters

    if (not $self->{CONTENT})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_CONTENT");
        return undef;
    }
    if (not $self->{CERT})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_CERT");
        return undef;
    }
    if (not $self->{KEY})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_KEY");
        return undef;
    }
    if ($self->{ENC_ALG} ne "aes256" and
        $self->{ENC_ALG} ne "aes192" and
        $self->{ENC_ALG} ne "aes128" and
        $self->{ENC_ALG} ne "idea" and
        $self->{ENC_ALG} ne "des3" and
        $self->{ENC_ALG} ne "des")
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_WRONG_ENC_ALG");
        return undef;
    }

    ## prepare data

    return undef
        if (not $self->write_file (FILENAME => $self->{CONTENTFILE},
                                   CONTENT  => $self->{CONTENT}));

    ## build the command

    my $command  = "smime -sign";
    $command .= " -nodetach" if (not $self->{DETACH});
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -inkey ".$self->{KEYFILE} if ($self->{KEYFILE});
    $command .= " -signer ".$self->{CERTFILE} if ($self->{CERTFILE});
    $command .= " -in ".$self->{CONTENTFILE};
    $command .= " -out ".$self->{OUTFILE};
    $command .= " -outform PEM";
    $command .= " -certfile t/crypto/cacert.pem";
    $command .= " -".$self->{ENC_ALG};

    if (defined $passwd)
    {
        $command .= " -passin env:pwd";
	$ENV{'pwd'} = $passwd;
        $self->{CLEANUP}->{ENV}->{PWD} = "pwd";
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
    return 0 if (exists $self->{CLEANUP}->{ENV}->{PWD});
    return 1;
}

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}

1;
