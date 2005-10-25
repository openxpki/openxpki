## OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_key
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_key;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->{OUT_PASSWD} = $self->{PASSWD}
        if (not exists $self->{OUT_PASSWD} and exists $self->{PASSWD});
    $self->{ENC_ALG} = "aes256" if (not exists $self->{ENC_ALG});

    my $engine = "";
       $engine = $self->{ENGINE}->get_engine() if ($self->{USE_ENGINE});

    $self->{KEYFILE} = $self->{TMP}."/${$}_key_org.pem";
    $self->{CLEANUP}->{FILE}->{KEY} = $self->{KEYFILE};
    $self->{OUTFILE} = $self->{TMP}."/${$}_key_new.pem";
    $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};
    $self->write_file (FILENAME => $self->{KEYFILE},
                       CONTENT  => $self->{DATA});

    ## check parameters

    if ($self->{ENC_ALG} ne "aes256" and
        $self->{ENC_ALG} ne "aes192" and
        $self->{ENC_ALG} ne "aes128" and
        $self->{ENC_ALG} ne "idea" and
        $self->{ENC_ALG} ne "des3" and
        $self->{ENC_ALG} ne "des")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_KEY_WRONG_ENC_ALG");
    }
    if (not exists $self->{PASSWD})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_KEY_MISSING_PASSWD");
    }
    if (not exists $self->{IN})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_KEY_MISSING_INPUT_FORMAT");
    }
    if ($self->{IN} ne "RSA" and
        $self->{IN} ne "DSA" and
        $self->{IN} ne "PKCS8")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_KEY_WRONG_INPUT_FORMAT");
    }
    if (not exists $self->{OUT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_KEY_MISSING_OUTPUT_FORMAT");
    }
    if ($self->{OUT} ne "PEM" and
        $self->{OUT} ne "DER" and
        $self->{OUT} ne "PKCS8")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_KEY_WRONG_OUTPUT_FORMAT");
    }
    if (not exists $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_KEY_MISSING_DATA");
    }

    ## build the command

    my $command  = "";
    if ($self->{OUT} eq "PKCS8")
    {
        $command = "pkcs8 -topk8";
        $command .= " -v2 ".$self->{ENC_ALG};
    }
    elsif ($self->{IN} eq "RSA")
    {
        $command = "rsa";
        $command .= " -".$self->{ENC_ALG};
    }
    elsif ($self->{IN} eq "DSA")
    {
        $command = "dsa";
        $command .= " -".$self->{ENC_ALG};
    }
    else
    {
        $command = "pkcs8";
        $command .= " -v2 ".$self->{ENC_ALG};
    }
    $command .= " -outform DER -inform PEM" if ($self->{OUT} eq "DER");
    $command .= " -engine $engine" if ($engine);
    $command .= " -in ".$self->{KEYFILE};
    $command .= " -out ".$self->{OUTFILE};

    if ($self->{PASSWD})
    {
        $command .= " -passin env:pwd";
        $ENV{'pwd'} = $self->{PASSWD};
        $self->{CLEANUP}->{ENV}->{PWD} = "pwd";
    }

    if ($self->{OUT_PASSWD})
    {
        $command .= " -passout env:outpwd";
        $ENV{'outpwd'} = $self->{OUT_PASSWD};
        $self->{CLEANUP}->{ENV}->{PWD} = "outpwd";
    }

    return [ $command ];
}

sub hide_output
{
    return 0;
}

sub key_usage
{
    return 1;
}

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}

1;
__END__

=head1 Description

This command should perform all conversions of keys. This includes
simple format conversions from PEM to DER and real tranformations
from proprietary OpenSSL RSA and DSA key to PKCS#8 format.

If there is a conversion towards PKCS#8 the result is always PEM
encoded. If you need a DER encoded PKCS#8 key then you must convert
the returned PEM encoded key again to DER.

If you convert a RSA or DSA key from OpenSSL's proprietary format
towards PKCS#8 then you must support us with a passphrase.

=head1 Functions

=head2 get_command

=over

=item * IN (RSA, DSA, PKCS8)

=item * OUT (DER, PEM, PKCS8)

=item * DATA

=item * PASSWD

=item * OUT_PASSWD (optional)

=item * ENC_ALG (optional)

=back

=head2 hide_output

returns 1 (key will only be displayed in encrypted form but the passphrase is present)

=head2 key_usage

returns 1 (private key must be decoded first)

=head2 get_result

simply returns the converted key

