package OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkcs10;
use OpenXPKI;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;



    ## check parameters

    if (not exists $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_MISSING_DATA");
    }
    if (! exists $self->{IN}) {
        # default input format is PEM
        $self->{IN} = 'PEM';
    }
    if ($self->{IN} ne 'PEM' && $self->{IN} ne 'DER') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_INCORRECT_INPUT_FORMAT',
            params  => {
                FORMAT => $self->{IN},
            },
        );
    }
    if (not exists $self->{OUT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_MISSING_OUTPUT_FORMAT");
    }
    if ($self->{OUT} ne "DER" && $self->{OUT} ne "TXT" && $self->{OUT} ne 'PEM')
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_WRONG_OUTPUT_FORMAT",
            params => { OUTPUT_FORMAT => $self->{OUT} });
    }

    ## build the command

    my $command  = "req";

    ## option '-engine' is needed here for correct req convertion
    ## in a case when engine introduces new crypto algorithms (like GOST ones),
    ## which are not available in a classical OpenSSL library
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $command .= " -engine ".$self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            ($engine_usage =~ m{ NEW_ALG }xms));

    $command .= " -out ".$self->get_outfile();
    $command .= " -in " . $self->write_temp_file( $self->{DATA} );
    $command .= " -inform " . $self->{IN};
    if ($self->{OUT} eq "DER") {
        $command .= " -outform DER";
    }
    elsif ($self->{OUT} eq 'PEM') {
        $command .= " -outform PEM";
    }
    else {
        $command .= " -noout -text -nameopt RFC2253,-esc_msb";
    }

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

#get_result moved to base class

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkcs10

=head1 Functions

=head2 get_command

=over

=item * DATA

=item * OUT (DER, TXT)

=back

=head2 hide_output

returns 0

=head2 key_usage

returns 0

=head2 get_result

simply returns the converted CSR

