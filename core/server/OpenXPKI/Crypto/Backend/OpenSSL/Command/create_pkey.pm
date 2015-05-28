## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkey

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkey;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    # check minimum requirements
    if (not exists $self->{PASSWD} || $self->{PASSWD} eq '' )
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKEY_MISSING_PASSWD");
    }

    # prepare parameters
    my $passwd = $self->{PASSWD};
    my $engine = $self->__get_used_engine();

    my $key_alg = $self->{KEY_ALG};
    my $enc_alg = $self->{ENC_ALG} || 'aes256';
    my $pkeyopt = $self->{PKEYOPT};

    if (defined $pkeyopt && ref $pkeyopt ne 'HASH') {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKEY_PKEYOPT_IS_NOT_HASH");
    }

    # PARAM holds the parameters blob for DSA, etc!
    if ($self->{PARAM}) {
        $self->get_tmpfile ('PARAM');
        $self->write_file (FILENAME => $self->{PARAMFILE},
            CONTENT  => $self->{PARAM},
            FORCE    => 1);
    } elsif (!$key_alg) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKEY_REQUIRE_KEY_ALG_OR_PARAM");
    }

    $self->get_tmpfile ('OUT');

    my @command = qw( genpkey );
    push @command, ('-engine', $engine) if ($engine);

    push @command, ('-out', $self->{OUTFILE});

    push @command, ('-algorithm', $key_alg) if ($key_alg); # no algorithm for e.g. DSA from params file
    foreach my $key (keys %{$pkeyopt}) {
        if (ref $pkeyopt->{$key} eq 'ARRAY') {
            map { push @command, ('-pkeyopt', $key.':'.$_ ); } @{$pkeyopt->{$key}};
        } else {
            push @command, ('-pkeyopt', $key.':'.$pkeyopt->{$key} );
        }
    }

    push @command, ('-paramfile', $self->{PARAMFILE}) if ($self->{PARAMFILE});
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

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkey

=head1 Functions

=head2 get_command

This is a wrapper for the openssl genpkey command, most of the parameters
are passed as is to openssl. See the openssl manpage of genpkey for options.

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
