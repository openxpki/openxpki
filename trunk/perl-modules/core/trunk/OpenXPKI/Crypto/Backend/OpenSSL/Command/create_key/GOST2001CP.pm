## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::GOST2001CP
## Written 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::GOST2001CP;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key);

sub new
{
    my $class      = shift;
    my $parent_ref = shift;
    my $self       = {};
    bless $self, $class;
    $self->{PARENT_REF} = $parent_ref;
    return $self;
}

sub verify_params
{
    my $self = shift;

    $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} = "aes256"
        if ( not exists $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} );
    if (     $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "aes256"
         and $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "aes192"
         and $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "aes128"
         and $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "idea"
         and $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "des3"
         and $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "des" )
    {
        OpenXPKI::Exception->throw( message =>
            "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_WRONG_ENC_ALG");
    }

    return 1;
}

sub get_command
{
    my $self   = shift;
    my $engine = shift;

    if (not $engine) {
        OpenXPKI::Exception->throw( message =>
            "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_NO_ENGINE_FOR_GOST");

    }
    my $command = "req -newkey gost2001cp:".$self->{PARENT_REF}->{PARAMETERS}->{PARAMSET};

    ## req wants profile of request to be filled, although it is not needed for key generation
    $command .= " -engine $engine";
    $command .= " -keyout " . $self->{PARENT_REF}->{OUTFILE};
    $command .= " -rand " . $self->{PARENT_REF}->{RANDOM_FILE};
    $command .= ' -subj "/dc=ru/dc=OpenXPKI/dc=key generation only/dc=gost2001cp"';
    $command .= " -noout -batch -nodes";

    return $command;
}

1;

__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::GOST2001CP

=head1 Description

This module is used to create GOST2001 keys in CP mode.
GOST2001 is a digital signature algorithm based on 
elliptic curves.
The module should never be used directly.

=head1 Functions

=head2 new

is the constructor. The passed argument is an instance of
OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key. The passed argument is
stored in the $self->{PARENT_REF} member. Some checks on consistency of the
passed object are done in the "grandfather" class
OpenXPKI::Crypto::Backend::OpenSSL::Command.

=head2 verify_params

This function verifies GOST2001CP-specific algorithm parameters.
Required parameter: PARAMSET. Possible values: "0", "A", "B", 
"C", "XA", "XB".

=head2 get_command

This is an implementation of the
OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::get_command
for GOST2001CP algorithm.
