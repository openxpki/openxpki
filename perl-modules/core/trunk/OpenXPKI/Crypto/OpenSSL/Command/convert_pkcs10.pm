## OpenXPKI::Crypto::OpenSSL::Command::convert_pkcs10
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::convert_pkcs10;

use base qw(OpenXPKI::Crypto::OpenSSL::Command);

=head1 Parameters

=over

=item * DATA

=item * OUT (DER, TXT)

=back

=cut

sub get_command
{
    my $self = shift;

    $self->{INFILE} = $self->{TMP}."/${$}_csr_org.pem";
    $self->{CLEANUP}->{FILE}->{IN} = $self->{INFILE};
    $self->{OUTFILE} = $self->{TMP}."/${$}_csr_new.pem";
    $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};
    $self->write_file (FILENAME => $self->{INFILE},
                       CONTENT  => $self->{DATA});

    ## check parameters

    if (not exists $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_MISSING_DATA");
    }
    if (not exists $self->{OUT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_MISSING_OUTPUT_FORMAT");
    }
    if ($self->{OUT} ne "DER" and $self->{OUT} ne "TXT")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_WRONG_OUTPUT_FORMAT");
    }

    ## build the command

    my $command  = "req";
    $command .= " -out ".$self->{OUTFILE};
    $command .= " -in ".$self->{INFILE};
    if ($self->{OUT} eq "DER")
    {
        $command .= " -outform DER";
    } else {
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
    return 1;
}

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}

1;
