## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Dmitry Belyavsky for the OpenXPKI project 
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);
use English;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::DSA;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::EC;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::GOST2001;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::GOST2001CP;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::GOST94;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::GOST94CP;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::RSA;

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
    my $key_store = $self->{ENGINE}->get_key_store();
    if (uc($self->{TOKEN_TYPE}) eq 'CA')
    {
        if ($key_store eq 'ENGINE') {
            ## token CA key generation
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_CANNOT_CREATE_TOKEN_KEY"); 
        }
        else {
            ## external CA key generation
            $passwd  = $self->{ENGINE}->get_passwd();
            $self->{KEYFILE} = $self->{ENGINE}->get_keyfile();
        }

    } else {
        ## external key generation
        $passwd = $self->{PASSWD};
        $self->get_tmpfile ('KEY');
    }
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $engine = $self->{ENGINE}->get_engine()
         if ($self->{ENGINE}->get_engine() and
             (($engine_usage =~ m{ ALWAYS }xms) or
              ($engine_usage =~ m{ PRIV_KEY_OPS }xms)));

    my $algclass = __PACKAGE__."::".$self->{TYPE};

    my $algobj = $algclass->new ($self);

    ## we do not need to check the result because 
    ## verify_params function throws an algorithm-specific 
    ## exception if any error occurs
    $algobj->verify_params();

## FIXME: $keyform was not set both in
## original and modified code. Michael, what it is for?

    if (not length($engine) and not defined $passwd)
    {
        ## missing passphrase
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_MISSING_PASSWD");
    }

    ## algorithm specific command
    my $command = $algobj->get_command($engine);

    if (! $command) {
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

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key

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
a passwd and perhaps ENGINE_USAGE if you want to use the engine of the
token too.

=over

=item * TYPE (DSA, EC or RSA)

=item * ENC_ALG

=item * KEY_LENGTH (if the TYPE equals DSA or RSA)

=item * CURVE_NAME (if the TYPE equals EC)

=item * RANDOM_FILE

=item * ENGINE_USAGE

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
