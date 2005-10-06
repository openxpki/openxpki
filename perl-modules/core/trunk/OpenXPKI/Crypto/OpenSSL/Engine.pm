## OpenXPKI::Crypto::OpenSSL::Engine 
## Copyright (C) 2003-2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Engine;

use OpenXPKI qw (i18nGettext debug);

our ($errno, $errval);

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
                DEBUG     => 0,
               };

    my $keys = { @_ };

    bless ($self, $class);
    $self->debug ("new: class instantiated");

    ## token mode will be ignored
    $self->{OPENSSL}      = $keys->{OPENSSL};
    $self->{NAME}         = $keys->{NAME};
    $self->{CA_GROUP}     = $keys->{CA_GROUP};
    $self->{KEY}          = $keys->{KEY};
    $self->{PASSWD}       = $keys->{PASSWD} if (exists $keys->{PASSWD});
    $self->{CERT}         = $keys->{PEM_CERT};
    $self->{CHAIN}        = $keys->{CHAIN};
    $self->{PASSWD_PARTS} = $keys->{PASSWD_PARTS};

    return $self;
}

sub login {
    my $self = shift;
    $self->{PASSWD} = $self->{CRYPTO}->get_ui()->get_token_passwd (
                          PARTS => $self->{PASSWD_PARTS},
                          TOKEN => $self->{NAME});

    return $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_OPENSSL_LOGIN_FAILED")
        if (not $self->{OPENSSL}->command ("convert_key", OUTFORM=>"PKCS8"));

    $self->{ONLINE} = 1;
    return 1;
}

sub logout {
    my $self = shift;
    undef $self->{PASSWD};
    $self->{ONLINE} = 0;
    return 1;
}

sub online {
    my $self = shift;
    return 1;
}

sub key_online {
    my $self = shift;
    return undef if (not $self->{ONLINE});
    return 1;
}

sub get_mode {
    return "standby";
}

sub is_dynamic
{
    return 1;
}

sub get_engine
{
    return "";
}

sub get_keyfile
{
    my $self = shift;
    return $self->{KEY};
}

sub get_passwd
{
    my $self = shift;
    return $self->{PASSWD} if (exists $self->{PASSWD});
    return undef;
}

sub get_certfile
{
    my $self = shift;
    return $self->{CERT};
}

sub get_chainfile
{
    my $self = shift;
    return $self->{CHAIN};
}

sub get_keyform
{
    ## do not return something with a leading "e"
    ## if you don't use an engine
    return "";
}

sub get_wrapper
{
    return "";
}

sub get_engine_params
{
    return "";
}

sub filter_stderr
{
    my $self = shift;
    return $_[0];
}

sub filter_stdout
{
    my $self = shift;
    return $_[0];
}

sub pin_callback
{
    return 1;
}

1;
