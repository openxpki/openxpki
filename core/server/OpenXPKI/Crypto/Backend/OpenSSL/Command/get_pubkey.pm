package OpenXPKI::Crypto::Backend::OpenSSL::Command::get_pubkey;
use OpenXPKI;

use parent qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    ##! 1: 'start'
    my $self = shift;

    ## compensate missing parameters
    $self->{KEYTYPE} = "pkey" if (not $self->{KEYTYPE});

    $self->{IN} = 'PEM' if (not $self->{IN});
    $self->{OUT} = 'PEM' if (not $self->{OUT});

    my $engine = $self->__get_used_engine('PRIV_KEY_OPS');

    ## check parameters
    if ($self->{KEYTYPE} !~ /\A(pkey|rsa|p384_mldsa65)\z/) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKEY_WRONG_KEYTYPE",
            params => { KEYTYPE => $self->{KEYTYPE} });
    }

    my $keytype = $self->{KEYTYPE};

    # PQC/hybrid keys must use generic EVP pkey command
    if ($keytype eq 'p384_mldsa65') {
        $keytype = 'pkey';
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

    #my @command = ($self->{KEYTYPE},
    #    "-pubout",
    #    "-in", $self->write_temp_file( $self->{DATA} )
    #);

    my @command = (
        $keytype,
        "-provider", "oqsprovider",
        "-provider", "default",
        "-pubout",
        "-in", $self->write_temp_file( $self->{DATA} )
    );

    if ($self->{IN} eq "DER") {
        push @command, "-inform","der";
    }

    if ($self->{PASSWD})
    {
        push @command, "-passin","env:pwd";
        $self->set_env ("pwd" => $self->{PASSWD});
    }

    if ($self->{OUT} eq "DER") {
        push @command, "-outform","der";
    }

    if ($engine) {
        push @command, "-engine", $engine;
    }

    push @command, "-out", $self->get_outfile();

    return [ \@command ];

}

sub hide_output
{
    return 1;
}

sub key_usage
{
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::get_pubkey

=head1 Description

Extract pubkey from a private key object using openssl pkey.

=head1 Functions

=head2 get_command

=over

=item * IN (PEM, DER)

=item * OUT (PEM, DER)

=item * DATA

=item * PASSWD

=back

=head2 get_result

simply returns the public key

