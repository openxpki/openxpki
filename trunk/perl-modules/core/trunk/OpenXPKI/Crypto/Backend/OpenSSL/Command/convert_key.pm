## OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_key
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## enhanced to support OpenSSL format keys and decryption 2006
## by Alexander Klink for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_key;

use strict;
use warnings;

use OpenXPKI::Debug;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);
use Data::Dumper;

sub get_command
{
    ##! 1: 'start' 
    my $self = shift;

    ## compensate missing parameters

    $self->{OUT_PASSWD} = $self->{PASSWD}
        if (not exists $self->{OUT_PASSWD} and exists $self->{PASSWD});
    $self->{ENC_ALG} = "aes256" if (not exists $self->{ENC_ALG});

    my $engine = "";
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    if ($self->{ENGINE}->get_engine() and 
        (($engine_usage =~ m{ NEW_ALG }xms) or 
         ($engine_usage =~ m{ ALWAYS }xms) or 
         ($engine_usage =~ m{ PRIV_KEY_OPS }xms))
       ) {
        $engine = $self->{ENGINE}->get_engine();
    }

    $self->get_tmpfile ('KEY', 'OUT', 'FIRSTOUT');
    $self->write_file (FILENAME => $self->{KEYFILE},
                       CONTENT  => $self->{DATA},
	               FORCE    => 1);

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
    if ($self->{OUT} ne "PEM" &&
        $self->{OUT} ne "DER" &&
        $self->{OUT} ne "PKCS8" && 
        $self->{OUT} ne "OPENSSL_RSA" &&
        $self->{OUT} ne "OPENSSL_DSA" &&
        $self->{OUT} ne "OPENSSL_EC")
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
    my $command2 = "";
    if ($self->{OUT} eq "PKCS8")
    {
        $command = "pkcs8 -topk8";
        if ($self->{DECRYPT}) {
            $command .= " -nocrypt";
        }
        else {
            $command .= " -v2 ".$self->{ENC_ALG};
        }
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
    elsif ($self->{OUT} eq 'OPENSSL_RSA')
    {
        $command  = "pkcs8 ";
        $command2 = "rsa ";
        if (! $self->{DECRYPT}) {
            $command2 .= '-' . $self->{ENC_ALG};
        }
        $command2 .= " -in " . $self->{FIRSTOUTFILE};
        $command2 .= " -out " . $self->{OUTFILE}; 
        $command2 .= " -engine $engine" if ($engine);
        if ($self->{OUT_PASSWD}) {
            $command2 .= " -passout env:outpwd";
            $self->set_env('outpwd' => $self->{OUT_PASSWD});
        }
    }
    elsif ($self->{OUT} eq 'OPENSSL_DSA')
    {
        $command  = "pkcs8 ";
        $command2 = "dsa ";
        if (! $self->{DECRYPT}) {
            $command2 .= '-' . $self->{ENC_ALG};
        }
        $command2 .= " -in " . $self->{FIRSTOUTFILE};
        $command2 .= " -out " . $self->{OUTFILE}; 
        $command2 .= " -engine $engine" if ($engine);
        if ($self->{OUT_PASSWD}) {
            $command2 .= " -passout env:outpwd";
            $self->set_env('outpwd' => $self->{OUT_PASSWD});
        }
    }
    elsif ($self->{OUT} eq 'OPENSSL_EC')
    {
        $command  = "pkcs8 ";
        $command2 = "ec ";
        if (! $self->{DECRYPT}) {
            $command2 .= '-' . $self->{ENC_ALG};
        }
        $command2 .= " -in " . $self->{FIRSTOUTFILE};
        $command2 .= " -out " . $self->{OUTFILE}; 
        $command2 .= " -engine $engine" if ($engine);
        if ($self->{OUT_PASSWD}) {
            $command2 .= " -passout env:outpwd";
            $self->set_env('outpwd' => $self->{OUT_PASSWD});
        }
    }
    else
    {
        $command = "pkcs8";
        if (! $self->{DECRYPT}) {
            $command .= " -v2 ".$self->{ENC_ALG};
        }
    }
    $command .= " -outform DER -inform PEM" if ($self->{OUT} eq "DER");
    $command .= " -engine $engine" if ($engine);
    $command .= " -in ".$self->{KEYFILE};

    if ($self->{OUT} eq 'OPENSSL_RSA' || $self->{OUT} eq 'OPENSSL_EC') {
        # we need to execute two commands when OPENSSL_RSA or OPENSSL_EC
        # is requested and we want the outfile to be the same as before,
        # so we output the first command to FIRSTOUTFILE
        $command .= " -out ".$self->{FIRSTOUTFILE};
    }
    else {
        $command .= " -out ".$self->{OUTFILE};
    }

    if ($self->{PASSWD})
    {
        $command .= " -passin env:pwd";
        $self->set_env ("pwd" => $self->{PASSWD});
    }

    if ($self->{OUT_PASSWD})
    {
        $command .= " -passout env:outpwd";
        $self->set_env ('outpwd' => $self->{OUT_PASSWD});
    }

    if ($self->{OUT} eq 'OPENSSL_RSA' || $self->{OUT} eq 'OPENSSL_EC') {
        return [ $command, $command2 ];
    }
    else {
        return [ $command ];
    }
}

sub hide_output
{
    return 1;
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

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_key

=head1 Description

This command should perform all conversions of keys. This includes
simple format conversions from PEM to DER and real tranformations
from proprietary OpenSSL RSA and DSA key to PKCS#8 format.

If there is a conversion towards PKCS#8 the result is always PEM
encoded. If you need a DER encoded PKCS#8 key then you must convert
the returned PEM encoded key again to DER.

If you convert a RSA or DSA key from OpenSSL's proprietary format
towards PKCS#8 then you must support us with a passphrase.

To convert to OpenSSL's propietary format, you need to specify
the key type, i.e. 'OPENSSL_RSA' as output format. If you need to
deal with keys with different types, you can get the type with
the 'get_pkcs8_keytype' command.

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

returns 1

=head2 key_usage

returns 1 (private key must be decoded first)

=head2 get_result

simply returns the converted key

