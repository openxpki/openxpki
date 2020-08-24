## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_params

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_params;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    # check minimum requirements
    if (!$self->{TYPE}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PARAMS_MISSING_TYPE");
    }

    my $engine = $self->__get_used_engine();

    my $pkeyopt = $self->{PKEYOPT};

    # if order is not important you can just pass a hash here
    if (defined $pkeyopt && ref $pkeyopt eq 'HASH') {
        $pkeyopt = [ $pkeyopt ];
    }

    if (defined $pkeyopt && ref $pkeyopt ne 'ARRAY') {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKEY_PKEYOPT_IS_NOT_HASH");
    }

    my @command = qw( genpkey );
    push @command, '-genparam';
    push @command, ('-out', $self->get_outfile());

    push @command, ('-algorithm', $self->{TYPE});
    foreach my $item (@{$pkeyopt}) {
        foreach my $key (keys %{$item}) {
            if (ref $item->{$key} eq 'ARRAY') {
                map { push @command, ('-pkeyopt', $key.':'.$_ ); } @{$item->{$key}};
            } else {
                push @command, ('-pkeyopt', $key.':'.$item->{$key} );
            }
        }
    }
    push @command, ('-engine', $engine) if ($engine);

    return [ \@command ];
}

sub __get_used_engine
{
    my $self = shift;
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    if ($self->{ENGINE}->get_engine() and
        ($engine_usage =~ m{ ALWAYS }xms)) {
        return $self->{ENGINE}->get_engine();
    }
    else {
        return "";
    }
}

sub hide_output
{
    return 0;
}

sub key_usage
{
    return 1;
}

#get_result moved to base class

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::create_params

=head1 Functions

=head2 get_command

This is a wrapper for the openssl genpkey command with genparams set.

=over

=item * TYPE

The algorithm, DSA or DH, no default

=item * PKEYOPT

A hashref of key/value pairs to be passed to pkeyopt. If value is
an array, multiple options are created using the same key.
If order of options is relevant wrap each key/value pair into an
arrayref.

=back

=head2 hide_output

returns false

=head2 key_usage

Returns true if the request is created for the engine's key.
Otherwise returns false.

=head2 get_result

Returns the (PEM encoded) parameter blob.
