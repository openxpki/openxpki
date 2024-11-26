package OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_crl;
use OpenXPKI;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;


    if (! exists $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CRL_MISSING_DATA");
    }
    if (! $self->{DATA}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CRL_DATA_EMPTY'
        );
    }

    ## check parameters

    if (not exists $self->{OUT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CRL_MISSING_OUTPUT_FORMAT");
    }
    if ($self->{OUT} ne 'DER' && $self->{OUT} ne 'TXT' && $self->{OUT} ne 'PEM')
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CRL_WRONG_OUTPUT_FORMAT",
            params => { OUTPUT_FORMAT => $self->{OUT} } );
    }

    ## build the command

    my $command  = "crl";
    $command .= " -out ".$self->get_outfile();
    $command .= " -in " .$self->write_temp_file( $self->{DATA} );
    if (defined $self->{IN} && ($self->{IN} eq 'DER')) {
        $command .= " -inform DER";
    }
    if ($self->{OUT} eq "DER")
    {
        $command .= " -outform DER";
    }
    elsif ($self->{OUT} eq 'PEM') {
        $command .= ' -outform PEM';
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

OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_crl

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

simply returns the converted CRL

