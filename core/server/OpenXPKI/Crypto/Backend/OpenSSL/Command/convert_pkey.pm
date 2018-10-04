package OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkey;

use strict;
use warnings;

use OpenXPKI::Debug;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);
use Data::Dumper;

sub get_command
{
    ##! 1: 'start'
    my $self = shift;

    ## compensate missing parameters
    $self->{ENC_ALG} = "aes256" if (not exists $self->{ENC_ALG});
    $self->{KEYTYPE} = "pkey" if (not $self->{KEYTYPE});

    $self->{IN} = 'PEM' if (not $self->{IN});
    $self->{OUT} = 'PEM' if (not $self->{OUT});

    my $engine = "";
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    if ($self->{ENGINE}->get_engine() and
        (($engine_usage =~ m{ NEW_ALG }xms) or
         ($engine_usage =~ m{ ALWAYS }xms) or
         ($engine_usage =~ m{ PRIV_KEY_OPS }xms))
       ) {
        $engine = $self->{ENGINE}->get_engine();
    }

    $self->get_tmpfile ('KEY', 'OUT' );
    $self->write_file (FILENAME => $self->{KEYFILE},
                       CONTENT  => $self->{DATA},
                       FORCE    => 1);

    ## check parameters

    if ($self->{KEYTYPE} !~ /\A(pkey|rsa)\z/) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKEY_WRONG_KEYTYPE",
            params => { KEYTYPE => $self->{KEYTYPE} });
    }

    if ($self->{ENC_ALG} !~ /\A(aes(128|192|256)|des3|idea)\z/) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKEY_WRONG_ENC_ALG",
            params => { ENC_ALG => $self->{ENC_ALG} });
    }

    if (not exists $self->{PASSWD})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKEY_MISSING_PASSWD");
    }

    if ($self->{IN} !~ m{ \A (PEM|DER) \z}xms) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKEY_WRONG_INPUT_FORMAT",
            params => { INPUT_FORMAT => $self->{IN} });
    }

    if (not exists $self->{OUT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKEY_MISSING_OUTPUT_FORMAT");
    }

    if ($self->{OUT} !~ m{ \A (PEM|DER) \z}xms) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKEY_WRONG_OUTPUT_FORMAT",
            params => { OUTPUT_FORMAT => $self->{OUT} });
    }

    if (not exists $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKEY_MISSING_DATA");
    }

    ## build the command

    my $command  = $self->{KEYTYPE} .  " -in ".$self->{KEYFILE};

    if ($self->{IN} eq "DER") {
        $command .= " -inform der";
    }

    if ($self->{PASSWD})
    {
        $command .= " -passin env:pwd";
        $self->set_env ("pwd" => $self->{PASSWD});
    }

    if ($self->{OUT} eq "DER") {
        $command .= " -outform der";
    }

    if ($self->{ENC_ALG} && !$self->{NOPASSWD}) {
        $command .= " -".$self->{ENC_ALG};
        $command .= " -passout env:outpwd";

        if ($self->{OUT_PASSWD}) {
            $self->set_env ('outpwd' => $self->{OUT_PASSWD});
        } elsif ($self->{PASSWD}) {
            $self->set_env ('outpwd' => $self->{PASSWD});
        } else {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKEY_MISSING_OUTPUT_PASSWORD");
        }
    }

    $command .= " -engine $engine" if ($engine);

    $command .= " -out ".$self->{OUTFILE};

    return [ $command ];

}

sub hide_output
{
    return 1;
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

OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkey

=head1 Description

Do transformations on openssl native key format. Can be used to change/strip
the password or convert between PEM and DER format or test a given password.

To export the key without password, you must explicitly set NOPASSWD to 1.

=head1 Functions

=head2 get_command

=over

=item * IN (PEM, DER)

=item * OUT (PEM, DER)

=item * DATA

=item * PASSWD

=item * OUT_PASSWD (optional)

=item * ENC_ALG (optional)

=item * NOPASSWD (optional)

=back

=head2 hide_output

returns 1

=head2 key_usage

returns 1 (private key must be decoded first)

=head2 get_result

simply returns the converted key

