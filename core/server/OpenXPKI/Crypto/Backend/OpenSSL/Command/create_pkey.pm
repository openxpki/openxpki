package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkey;
use OpenXPKI;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    # check minimum requirements
    if (not exists $self->{PASSWD} || $self->{PASSWD} eq '' )
    {
        OpenXPKI::Exception->throw (
            message => "genpkey requires a password");
    }

    # prepare parameters
    my $passwd = $self->{PASSWD};
    my $engine = $self->__get_used_engine();

    my $key_alg = $self->{KEY_ALG};
    my $enc_alg = $self->{ENC_ALG} || 'aes256';
    my $pkeyopt = $self->{PKEYOPT};

    # if order is not important you can just pass a hash here
    if (defined $pkeyopt && ref $pkeyopt eq 'HASH') {
        $pkeyopt = [ $pkeyopt ];
    }

    # each array element must have at least one hashref
    if (defined $pkeyopt && ref $pkeyopt ne 'ARRAY') {
        OpenXPKI::Exception->throw (
            message => "pkeyopts must be an array of hashes");
    }

    if (!$key_alg && !$self->{PARAM}) {
        OpenXPKI::Exception->throw (
            message => "no algorithm given for genpkey");
    }

    my @command = qw( genpkey );
    push @command, ('-engine', $engine) if ($engine);

    push @command, ('-out', $self->get_outfile());

    push @command, ('-algorithm', $key_alg) if ($key_alg); # no algorithm for e.g. DSA from params file

    foreach my $item (@{$pkeyopt}) {
        foreach my $key (keys %{$item}) {
            if (ref $item->{$key} eq 'ARRAY') {
                map { push @command, ('-pkeyopt', $key.':'.$_ ); } @{$item->{$key}};
            } else {
                push @command, ('-pkeyopt', $key.':'.$item->{$key} );
            }
        }
    }

    # PARAM holds the parameters blob for DSA, etc!
    if ($self->{PARAM}) {
        push @command, ('-paramfile', $self->write_temp_file( $self->{PARAM} ) );
    }

    push @command, ('-'.$enc_alg);
    push @command, ('-pass', 'env:pwd');
    $self->set_env ("pwd" => $passwd);

    return [ \@command ];
}

sub __get_used_engine
{
    my $self = shift;
    my $engine_usage = $self->{ENGINE}->get_engine_usage();

    if ($self->{ENGINE}->get_engine() and
        (($engine_usage =~ m{ (ALWAYS|RANDOM|PRIV_KEY_GEN) }xms))) {
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

OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkey

=head1 Functions

=head2 get_command

This is a wrapper for the openssl genpkey command, most of the parameters
are passed as is to openssl. See the openssl manpage of genpkey for options.

If you want to use the engine then you must set
ENGINE_USAGE ::= ALWAYS||RANDOM||PRIV_KEY_GEN

=over

=item * PASSWD

The password to encrypt the private key with, this is the only mandatory
parameter

=item * KEY_ALG

The key algorithm, default is RSA.

=item * ENC_ALG

Algorithm to encrypt the private key, default is aes256.

=item * PKEYOPT

A hashref of key/value pairs to be passed to pkeyopt. If value is
an array, multiple options are created using the same key.
If order of options is relevant wrap each key/value pair into an
arrayref.

=item * PARAMFILE

Filename, passed to openssl paramfile.

=back

=head2 hide_output

returns false

=head2 key_usage

Returns true if the request is created for the engine's key.
Otherwise returns false.

=head2 get_result

Returns the newly created PEM encoded PKCS#8 private key.
