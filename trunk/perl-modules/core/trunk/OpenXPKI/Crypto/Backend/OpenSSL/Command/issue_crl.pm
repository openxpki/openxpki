## OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_crl
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_crl;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

use OpenXPKI;
use OpenXPKI::DateTime;

use Math::BigInt;
use English;

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    if (not $self->{PROFILE} or
        not ref $self->{PROFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_MISSING_PROFILE");
    }
    $self->{CONFIG}->set_profile($self->{PROFILE});

    $self->get_tmpfile ('OUT');

    ## ENGINE key's cert: no parameters
    ## normal cert: engine (optional), passwd, key

    my ($engine, $keyform, $passwd, $key) = ("", "", undef);
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $engine  = $self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            (($engine_usage =~ m{ ALWAYS }xms) or
             ($engine_usage =~ m{ PRIV_KEY_OPS }xms)));
    $keyform = $self->{ENGINE}->get_keyform();
    $passwd  = $self->{ENGINE}->get_passwd();
    $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
    #this is now in the openssl config
    #$self->{CERTFILE} = $self->{ENGINE}->get_certfile();

    ## check parameters

    if (not $self->{KEYFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_MISSING_KEYFILE");
    }
    my $key_store = $self->{ENGINE}->get_key_store();
    if ( (uc($self->{TOKEN_TYPE}) ne 'CA') or ($key_store ne 'ENGINE'))
    {
        if (not -e $self->{KEYFILE})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_KEYFILE_DOES_NOT_EXIST");
        }
    }

    ## prepare data

    if ($self->{REVOKED})
    {
        $self->{CONFIG}->set_cert_list($self->{REVOKED});
    }

    ## build the command

    my $command  = "ca -gencrl";
    #done by CLI
    #$command .= " -config $config";
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -out ".$self->{OUTFILE};

    if (defined $passwd)
    {
        $command .= " -passin env:pwd";
        $self->set_env ("pwd" => $passwd);
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

OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_crl

=head1 Functions

=head2 get_command

=over

=item * SERIAL

=item * DAYS

=item * START

=item * ENC

=item * REVOKED

This parameter is an ARRAY reference. The elements of this array enumerate
all certificates to be placed on the CRL.

For details on the format of this parameter please refer to
OpenXPKI::Crypto::Backend::OpenSSL::Config::set_cert_list

=back

=head2 hide_output

returns false

=head2 key_usage

returns true

=head2 get_result

returns the new CRL
