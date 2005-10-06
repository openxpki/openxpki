## OpenXPKI::Crypto::OpenSSL::Command::pkcs7_decrypt
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::pkcs7_decrypt;

use base qw(OpenXPKI::Crypto::OpenSSL::Command);

=head1 Parameters

If you want to decrypt a PKCS#7 structure with the used engine/token then you have
only to specify the PKCS7.

If you want to decrypt a normal PKCS#7 structure then you must specify at minimum
a CERT, a KEY and a PASSWD. If you want to use the engine then you must use
USE_ENGINE too.

=over

=item * PKCS7

=item * USE_ENGINE (optional)

=item * CERT

=item * KEY

=item * PASSWD

=back

=cut

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->{PKCS7FILE} = $self->{TMP}."/${$}_pkcs7.pem";
    $self->{CLEANUP}->{FILE}->{PKCS7} = $self->{PKCS7FILE};
    $self->{OUTFILE} = $self->{TMP}."/${$}_content.pem";
    $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};

    my ($engine, $passwd, $keyform);
    if ($self->{PASSWD} or $self->{KEY})
    {
        ## external pkcs#7 structure

        # check minimum requirements
        if (not exists $self->{PASSWD})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_PASSWD");
        }
        if (not exists $self->{KEY})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_KEY");
        }
        if (not exists $self->{CERT})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_CERT");
        }

        # prepare parameters

        $passwd = $self->{PASSWD};
        $engine = $self->{ENGINE}->get_engine() if ($self->{USE_ENGINE});

        $self->{KEYFILE} = $self->{TMP}."/${$}_key.pem";
        $self->{CLEANUP}->{FILE}->{KEY} = $self->{KEYFILE};
        $self->write_file (FILENAME => $self->{KEYFILE},
                           CONTENT  => $self->{KEY});

        $self->{CERTFILE} = $self->{TMP}."/${$}_cert.pem";
        $self->{CLEANUP}->{FILE}->{CERT} = $self->{CERTFILE};
        $self->write_file (FILENAME => $self->{CERTFILE},
                           CONTENT  => $self->{CERT});
    } else {
        ## token signature
        $engine  = $self->{ENGINE}->get_engine();
        $keyform = $self->{ENGINE}->get_keyform();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
        $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
    }

    ## check parameters

    if (not $self->{PKCS7})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_PKCS7");
    }
    if (not $self->{CERT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_CERT");
    }
    if (not $self->{KEY})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_KEY");
    }

    ## prepare data

    $self->write_file (FILENAME => $self->{PKCS7FILE},
                       CONTENT  => $self->{PKCS7});

    ## build the command

    my $command  = "smime -decrypt";
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -inkey ".$self->{KEYFILE} if ($self->{KEYFILE});
    $command .= " -recip ".$self->{CERTFILE} if ($self->{CERTFILE});
    $command .= " -inform PEM";
    $command .= " -in ".$self->{PKCS7FILE};
    $command .= " -out ".$self->{OUTFILE};

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
