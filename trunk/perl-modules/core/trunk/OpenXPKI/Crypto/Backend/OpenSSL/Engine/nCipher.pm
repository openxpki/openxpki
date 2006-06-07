## OpenXPKI::Crypto::Backend::OpenSSL::Engine::nCipher 
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision: 192 $

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Engine::nCipher;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Engine);
use OpenXPKI::Debug 'OpenXPKI::Crypto::Backend::OpenSSL::Engine::nCipher';
use OpenXPKI::Exception;
use English;
use OpenXPKI::Server::Context qw( CTX );

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    my $keys = { @_ };

    bless ($self, $class);
    ##! 2: "new: class instantiated"

    ## token mode will be ignored
    foreach my $key (qw{OPENSSL
                        NAME
                        KEY
                        PASSWD
                        PASSWD_PARTS
                        CERT
                        INTERNAL_CHAIN
                        ENGINE_SECTION
                        ENGINE_USAGE
			KEY_STORE
			WRAPPER
                       }) {

        if (exists $keys->{$key}) {
            $self->{$key} = $keys->{$key};
        }
    }
    $self->__check_engine_usage();
    $self->__check_key_store();

    return $self;
}

sub is_dynamic
{
    return 0;
}

sub get_engine
{
    return "chil";
}

sub get_keyform
{
    ## do not return something with a leading "e"
    ## if you don't use an engine
    return "engine";
}

sub get_wrapper
{
    my $self = shift;
    return $self->{WRAPPER};
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Engine::nCipher

=head1 Description

This class is the base class and the interface of all other engines.
This defines the interface how HSMs are supported by OpenXPKI.

=head1 Functions

=head2 new

The constructor supports the following parameters:

=over

=item * OPENSSL (the OpenSSL binary)

=item * NAME (a symbolic name for the token)

=item * KEY (filename of the key)

=item * PASSWD (sometimes keys are passphrase protected)

=item * PASSWD_PARTS (number of the parts of the passphrase)

=item * CERT (filename of the certificate)

=item * INTERNAL_CHAIN (filename of the certificate chain)

=item * ENGINE_USAGE (type of the crypto operations where engine should be used)

=item * KEY_STORE (storage type of the token's private key - could be OPENXPKI or ENGINE)

=item * WRAPPER (wrapper for the OpenSSL binary)

=item * ENGINE_SECTION (a part of the OpenSSL configuration file for the engine)

=back

=head2 is_dynamic

returns true if a dynamic OpenSSL engine is used.

=head2 get_engine

returns the used OpenSSL engine or the empty string if no engine
is used.

=head2 get_keyform

returns "e" or "engine" if the key is stored in an OpenSSL engine.

=head2 get_wrapper

returns the wrapper around the OpenSSL binary if such a
wrapper is used (e.g. nCipher's chil engine). Otherwise the empty string
is returned.
