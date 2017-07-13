use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::asn1_genconf;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    if (!$self->{DATA}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ASN1_GENCONF_DATA_MISSING"
        );
    }

    $self->get_tmpfile ('IN');
    $self->write_file (
        FILENAME => $self->{INFILE},
        CONTENT  => $self->{DATA},
        FORCE    => 1);

    $self->get_tmpfile ('OUT');

    my $command = "asn1parse ";

    $command .= "-genconf " . $self->{INFILE};
    $command .= " -out ". $self->{OUTFILE};


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
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}


1;
__END__
