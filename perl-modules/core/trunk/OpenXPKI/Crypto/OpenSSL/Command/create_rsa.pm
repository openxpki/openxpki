## OpenXPKI::Crypto::OpenSSL::Command::create_rsa
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::create_rsa;

use OpenXPKI::Crypto::OpenSSL::Command;
use vars qw(@ISA);
@ISA = qw(OpenXPKI::Crypto::OpenSSL::Command);

=head1 Parameters

If you want to create a key for the used engine then you have
only to specify the ENC_ALG and KEY_LENGTH. Perhaps you can specify
the RANDOM_FILE too.

If you want to create a normal key then you must specify at minimum
a passwd and perhaps USE_ENGINE if you want to use the engine of the
token too.

=over

=item * ENC_ALG

=item * KEY_LENGTH

=item * RANDOM_FILE

=item * USE_ENGINE

=item * PASSWD

=back

=cut

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->{ENC_ALG} = "aes256" if (not exists $self->{ENC_ALG});
    if (not exists $self->{RANDOM_FILE})
    {
        $self->{RANDOM_FILE} = $self->{TMP}."/.rand_${$}";
        $self->{CLEANUP}->{FILE}->{RANDOM} = $self->{RANDOM_FILE};
    }

    ## ENGINE key: no parameters
    ## normal key: engine (optional), passwd

    my ($engine, $keyform, $passwd) = ("", "", undef);
    if ($self->{PASSWD})
    {
        ## external key generation
        $passwd = $self->{PASSWD};
        $engine = $self->{ENGINE}->get_engine() if ($self->{USE_ENGINE});
        $self->{OUTFILE} = $self->{TMP}."/${$}_rsa.pem";
        $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};
    } else {
        ## token key generation
        $engine  = $self->{ENGINE}->get_engine();
        $keyform = $self->{ENGINE}->get_keyform();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{OUTFILE} = $self->{ENGINE}->get_keyfile();
    }

    ## check parameters

    if ($self->{ENC_ALG} ne "aes256" and
        $self->{ENC_ALG} ne "aes192" and
        $self->{ENC_ALG} ne "aes128" and
        $self->{ENC_ALG} ne "idea" and
        $self->{ENC_ALG} ne "des3" and
        $self->{ENC_ALG} ne "des")
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_RSA_WRONG_ENC_ALG");
        return undef;
    }
    if ($self->{KEY_LENGTH} != 512 and
        $self->{KEY_LENGTH} != 768 and
        $self->{KEY_LENGTH} != 1024 and
        $self->{KEY_LENGTH} != 2048 and
        $self->{KEY_LENGTH} != 4096)
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_RSA_WRONG_KEY_LENGTH");
        return undef;
    }
    if ($keyform ne "engine" and not defined $passwd)
    {
        ## missing passphrase
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_RSA_MISSING_PASSWD");
        return undef;
    }

    ## build the command

    my $command  = "genrsa";
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -".$self->{ENC_ALG};
    $command .= " -out ".$self->{OUTFILE};
    $command .= " -rand ".$self->{RANDOM_FILE};

    if (defined $passwd)
    {
        $command .= " -passout env:pwd";
	$ENV{'pwd'} = $passwd;
        $self->{CLEANUP}->{ENV}->{PWD} = "pwd";
    }

    $command .= " ".$self->{KEY_LENGTH};

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
