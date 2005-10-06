## OpenXPKI::Crypto::OpenSSL::Command::create_random
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::create_random;

use base qw(OpenXPKI::Crypto::OpenSSL::Command);

=head1 Parameters

Please note that all length specification are bytes. The returned
string only includes base64 characters. It is strongly recommended
to specifiy the required number of secure bytes and not the required
return length.

=over

=item * RETURN_LENGTH

=item * RANDOM_LENGTH

=back

=cut

sub get_command
{
    my $self = shift;

    my $length = 0;
    if ($self->{RETURN_LENGTH})
    {
        $length = $self->{RETURN_LENGTH};
    }
    if ($self->{RANDOM_LENGTH})
    {
        $length = $self->{RANDOM_LENGTH};
    }
    if (not $length)
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_RANDOM_MISSING_LENGTH");
        return undef;
    }

    my $command = "";
    $command .= "rand -base64";
    $command .= " -engine ".$self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine());
    $command .= " $length";

    return [ $command ];
}

sub hide_output
{
    return 1;
}

sub key_usage
{
    return 0;
}

sub get_result
{
    my $self   = shift;
    my $random = shift;

    ## remove trailing newline
    ## remove trailing =
    $random =~ s/\n//gs;
    $random =~ s/=*$//gs;

    if ($self->{RETURN_LENGTH} and not $self->{RANDOM_LENGTH}) {
        $random = substr ($random, 0, $self->{RETURN_LENGTH});
    }

    if (not defined $random or not length($random))
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_RANDOM_EMPTY");
        return undef;
    }

    return $random;
}

1;
