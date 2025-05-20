package OpenXPKI::Crypto::Backend::OpenSSL::Command::asn1_genconf;
use OpenXPKI;

use parent qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    if (!$self->{DATA}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ASN1_GENCONF_DATA_MISSING"
        );
    }



    my $command = "asn1parse ";

    $command .= "-genconf " . $self->write_temp_file( $self->{DATA} );
    $command .= " -out ". $self->get_outfile();


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

#get_result moved to base class


1;
__END__
