## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::EC
## Written 2006 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Dmitry Belyavsky for the OpenXPKI project
## Fixed 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::EC;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key);

sub new {
    my $class = shift;
    my $parent_ref = shift;
    my $self = {};
    bless $self, $class;
    $self->{PARENT_REF} = $parent_ref;
    return $self;
}

sub verify_params 
{
    my $self = shift;

    $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} = "aes256"
        if (not exists $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG});
    if ($self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "aes256" and
        $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "aes192" and
        $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "aes128" and
        $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "idea" and
        $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "des3" and
        $self->{PARENT_REF}->{PARAMETERS}->{ENC_ALG} ne "des")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_WRONG_ENC_ALG");
    }

    if ($self->{PARENT_REF}->{PARAMETERS}->{CURVE_NAME} !~ /^(secp|prime|sect|c2pnb|c2tnb)[1-9][0-9]{2}?[krvw][1-3]$/i and
        #there is no default algorithm!!!
        #$self->{PARENT_REF}->{PARAMETERS}->{CURVE_NAME} !~ /^$/ and
        $self->{PARENT_REF}->{PARAMETERS}->{CURVE_NAME} !~ /^Oakley-EC2N-[34]$/ and
        $self->{PARENT_REF}->{PARAMETERS}->{CURVE_NAME} !~ /^wap-wsg-idm-ecid-wtls[0-9]*$/)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_WRONG_EC_CURVE_NAME");
    }

    return 1;
}

sub get_command
{
    my $self = shift;
    my $engine = shift;

    my $command .= "ecparam -genkey";
    $command .= " -out ".$self->{PARENT_REF}->{OUTFILE};
    $command .= " -name ".$self->{PARENT_REF}->{PARAMETERS}->{CURVE_NAME};
    $command .= " -engine $engine" if ($engine);
    $command .= " -rand ".$self->{PARENT_REF}->{RANDOM_FILE};

    return $command;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::EC

=head1 Description

The module should never be used directly.
This command creates EC keys.

=head1 Functions

=head2 new

is the constructor. The passed argument is an instance of
OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key. The passed argument is
stored in the $self->{PARENT_REF} member. Some checks on consistency of the
passed object are done in the "grandfather" class
OpenXPKI::Crypto::Backend::OpenSSL::Command.

=head2 verify_params

This function verifies EC-specific algorithm parameters.

=head2 get_command

This is an implementation of the 
OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::get_command
for EC algorithm.

