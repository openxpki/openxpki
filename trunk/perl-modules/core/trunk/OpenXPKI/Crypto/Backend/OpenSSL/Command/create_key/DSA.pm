## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::DSA
## Written 2006 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Dmitry Belyavsky for the OpenXPKI project
## Fixed 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::DSA;

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

    if ($self->{PARENT_REF}->{PARAMETERS}->{KEY_LENGTH} != 512 and
        $self->{PARENT_REF}->{PARAMETERS}->{KEY_LENGTH} != 768 and
        $self->{PARENT_REF}->{PARAMETERS}->{KEY_LENGTH} != 1024 and
        $self->{PARENT_REF}->{PARAMETERS}->{KEY_LENGTH} != 2048 and
        $self->{PARENT_REF}->{PARAMETERS}->{KEY_LENGTH} != 4096)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_KEY_WRONG_KEY_LENGTH");
    }

    return 1;
}

sub get_command
{
    my $self = shift;
    my $engine = shift;

    my $command = "dsaparam -genkey";
    $command .= " -out ".$self->{PARENT_REF}->{OUTFILE};
    $command .= " -engine $engine" if ($engine);
    $command .= " -rand ".$self->{PARENT_REF}->{RANDOM_FILE};
    $command .= " ".$self->{PARENT_REF}->{PARAMETERS}->{KEY_LENGTH};

    return $command;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::DSA

=head1 Description

The module should never be used directly.
This command creates DSA keys.

=head1 Functions

=head2 new

is the constructor. The passed argument is an instance of
OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key. The passed argument is
stored in the $self->{PARENT_REF} member. Some checks on consistency of the
passed object are done in the "grandfather" class
OpenXPKI::Crypto::Backend::OpenSSL::Command.

=head2 verify_params

This function verifies DSA-specific algorithm parameters.

=head2 get_command

This is an implementation of the 
OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key::get_command
for DSA algorithm.

