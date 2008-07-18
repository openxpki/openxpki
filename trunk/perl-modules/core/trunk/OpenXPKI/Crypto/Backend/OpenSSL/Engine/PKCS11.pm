## OpenXPKI::Crypto::Backend::OpenSSL::Engine 
## Copyright (C) 2003-2007 Michael Bell

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Engine::PKCS11;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Engine);
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use English;
use OpenXPKI::Server::Context qw( CTX );

use Data::Dumper;

sub login {
    my $self = shift;
    my $keys = shift;

    ## check the supplied parameter
    if (not $self->{SECRET}->is_complete())
    {
        ## enforce passphrases
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_OPENSSL_LOGIN_INCOMPLETE_SECRET");
    }
    $self->{PASSWD} = $self->{SECRET}->get_secret();
    if (length $self->{PASSWD} < 4)
    {
        ## enforce OpenSSL default passphrase length
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_OPENSSL_LOGIN_PASSWD_TOO_SHORT");
    }

    ## test the passphrase
    ## we cannot transparently test the passphrase of a smartcard
    ## so we do not do it

    $self->{ONLINE} = 1;
    return 1;
}

sub get_engine
{
    return "pkcs11";
}


sub get_engine_section
{
    my $self = shift;

    if (length ($self->get_engine()) and
        exists $self->{ENGINE_SECTION} and
        length ($self->{ENGINE_SECTION}))
    {
        my $text = $self->{ENGINE_SECTION};
        if ($self->key_usable())
        {
            my $pin = $self->get_passwd();
            $text =~ s/__PIN__/$pin/;
        }
        return $self->{ENGINE_SECTION};
    } else {
        return "";
    }
}

sub get_keyform
{
    ## do not return something with a leading "e"
    ## if you don't use an engine
    return "engine";
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Engine::PKCS11

=head1 Description

This class implements an interface for OpenSC's PKCS#11 engine.

=head1 Configuration

You must configure an ENGINE_SECTION which looks like this:

 --snip--
 pkcs11 = pkcs11_section
   
 [pkcs11_section] 
 engine_id = pkcs11
 dynamic_path = /usr/lib/engines/engine_pkcs11.so
 MODULE_PATH = /usr/lib/opensc-pkcs11.so
 init = 0
 --snip--

Please note that the key file which must be specified in the configuration
must be the idenitifier of the key on the smartcard an not a real filename.
A typical OpenSC example for a name is id_45.

=head1 Functions

=head2 login

tries to set the passphrase for the used token. Actually we cannot check
the passphrase without risking to lock the smartcard or whatever token
is used. If the passhrase is missing or shorter than 4 characters
then an exception is thrown. There is no parameter because
we get the passphrase from the OpenXPKI::Crypto::Secret object.

Examples: $engine->login ();

=head2 get_engine

returns the used OpenSSL engine pkcs11.

=head2 get_engine_section

returns the OpenSSL engine section from the configuration. Please note
that this configuration must include a PIN line where the value of the
PIN parameter is __PIN__. This is necessary because this is the only
way how we can supply the PIN to the PKCS#11 library.

=head2 get_keyform

returns "engine" because otherwise the use of this module makes no sense.
