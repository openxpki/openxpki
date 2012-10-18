## OpenXPKI::Crypto::Backend::OpenSSL::Command::is_prime
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::is_prime;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    my $prime;
    if (defined $self->{PRIME}) {
        $prime = $self->{PRIME};
    }
    else {
        OpenXPKI::Exception->throw (
            message =>
                "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_IS_PRIME_MISSING_PRIME",
        );
    }
    
    my $command = "";
    $command .= "prime -hex $prime";

    return [ $command ];
}

sub hide_output
{
    return 0;
}

sub key_usage
{
    return 0;
}

sub get_result
{
    my $self   = shift;
    my $result = shift;

    if ($result =~ /is not prime/) {
        return undef;
    }
    else {
        return 1;
    }
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::is_prime

=head1 Functions

=head2 get_command

Checks whether a given hexadecimal number (the parameter "PRIME") is a
prime or not. 

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

Returns undef if it is not a prime and 1 if it is.
