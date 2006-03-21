## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;
    my $return = undef;

    ## compensate missing parameters

    if (not exists $self->{RANDOM_FILE})
    {
	$self->get_tmpfile ('RANDOM_');
    }
    $self->get_tmpfile ('OUT');

    ## ENGINE key: no parameters
    ## normal key: engine (optional), passwd

    my ($engine, $keyform, $passwd) = ("", "", undef);
    if ($self->{PASSWD})
    {
        ## external key generation
        $passwd = $self->{PASSWD};
        $engine = $self->{ENGINE}->get_engine() if ($self->{USE_ENGINE});
        $self->get_tmpfile ('KEY');
    } else {
        ## token key generation
        $engine  = $self->{ENGINE}->get_engine();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{KEYFILE} = $self->{ENGINE}->get_keyfile();
    }

    ## check parameters

    if ($self->{TYPE} eq "RSA" or
        $self->{TYPE} eq "DSA" or
        $self->{TYPE} eq "EC")
    {
        $self->{PARAMETERS}->{ENC_ALG} = "aes256"
            if (not exists $self->{PARAMETERS}->{ENC_ALG});
        if ($self->{PARAMETERS}->{ENC_ALG} ne "aes256" and
            $self->{PARAMETERS}->{ENC_ALG} ne "aes192" and
            $self->{PARAMETERS}->{ENC_ALG} ne "aes128" and
            $self->{PARAMETERS}->{ENC_ALG} ne "idea" and
            $self->{PARAMETERS}->{ENC_ALG} ne "des3" and
            $self->{PARAMETERS}->{ENC_ALG} ne "des")
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_WRONG_ENC_ALG");
        }
    }

    if ($self->{TYPE} eq "EC")
    {
        if ($self->{PARAMETERS}->{CURVE_NAME} !~ /^(secp|prime|sect|c2pnb|c2tnb)[1-9][0-9]{2}?[krvw][1-3]$/i and
            $self->{PARAMETERS}->{CURVE_NAME} !~ /^$/ and
            $self->{PARAMETERS}->{CURVE_NAME} !~ /^Oakley-EC2N-[34]$/ and
            $self->{PARAMETERS}->{CURVE_NAME} !~ /^wap-wsg-idm-ecid-wtls[0-9]*$/)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_WRONG_EC_CURVE_NAME");
        }
    }
    elsif ($self->{TYPE} eq "RSA" or $self->{TYPE} eq "DSA")
    {
        if ($self->{PARAMETERS}->{KEY_LENGTH} != 512 and
            $self->{PARAMETERS}->{KEY_LENGTH} != 768 and
            $self->{PARAMETERS}->{KEY_LENGTH} != 1024 and
            $self->{PARAMETERS}->{KEY_LENGTH} != 2048 and
            $self->{PARAMETERS}->{KEY_LENGTH} != 4096)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_WRONG_KEY_LENGTH");
        }
    }
    else
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_UNSUPPORTED_TYPE",
            params  => {"TYPE" => $self->{TYPE}});
    }
    if ($keyform ne "engine" and not defined $passwd)
    {
        ## missing passphrase
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_MISSING_PASSWD");
    }

    ## algorithm specific command

    my $command = "";
    if ($self->{TYPE} eq "DSA")
    {
        $command .= "dsaparam -genkey";
        $command .= " -out ".$self->{OUTFILE};
        $command .= " -engine $engine" if ($engine);
        $command .= " -rand ".$self->{RANDOM_FILE};
        $command .= " ".$self->{PARAMETERS}->{KEY_LENGTH};
    }
    elsif ($self->{TYPE} eq "EC")
    {
        $command .= "ecparam -genkey";
        $command .= " -out ".$self->{OUTFILE};
        $command .= " -name ".$self->{PARAMETERS}->{CURVE_NAME};
        $command .= " -engine $engine" if ($engine);
        $command .= " -rand ".$self->{RANDOM_FILE};
    }
    elsif ($self->{TYPE} eq "RSA")
    {
        $command .= "genrsa";
        $command .= " -engine $engine" if ($engine);
        $command .= " -out ".$self->{OUTFILE};
        $command .= " -rand ".$self->{RANDOM_FILE};
        $command .= " ".$self->{PARAMETERS}->{KEY_LENGTH};
    }
    else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_OPENSSL_COMMAND_CREATE_KEY_UNSUPPORTED_TYPE",
            params  => {"TYPE" => $self->{TYPE}});
    }

    ## PKCS# 8 conversion incl. passphrase setting

    ## build the command

    my $pkcs8  = "pkcs8 -topk8";
       $pkcs8 .= " -v2 ".$self->{PARAMETERS}->{ENC_ALG};
       $pkcs8 .= " -engine $engine" if ($engine);
       $pkcs8 .= " -in ".$self->{OUTFILE};
       $pkcs8 .= " -out ".$self->{KEYFILE};

    if ($passwd)
    {
        $pkcs8 .= " -passout env:pwd";
        $self->set_env ('pwd' => $passwd);
    }

    return [ $command, $pkcs8 ];
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
    return $self->read_file ($self->{KEYFILE});
}

1;
__END__

=head1 Description

This command creates keys. Actually we support EC, DSA and RSA
keys. The function creates always PKCS#8 keys. This ensures that
you never have to take care about the type of the key after the
key was generated.

=head1 Functions

=head2 get_command

If you want to create a key for the used engine then you have
only to specify the ENC_ALG and KEY_LENGTH. Perhaps you can specify
the RANDOM_FILE too.

If you want to create a normal key then you must specify at minimum
a passwd and perhaps USE_ENGINE if you want to use the engine of the
token too.

=over

=item * TYPE (DSA, EC or RSA)

=item * ENC_ALG

=item * KEY_LENGTH (if the TYPE equals DSA or RSA)

=item * CURVE_NAME (if the TYPE equals EC)

=item * RANDOM_FILE

=item * USE_ENGINE

=item * PASSWD

=back

Example:

$token->command ("COMMAND"    => "create_key",
                 "TYPE"       => "RSA",
                 "PARAMETERS" => {
                     "ENC_ALG"    => "aes128",
                     "KEY_LENGTH" => "1024"});

=head2 hide_output

returns true

=head2 key_usage

returns true

=head2 get_result

returns the new encrypted key
