## OpenXPKI::Crypto::OpenSSL::Command::pkcs7_get_chain
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::pkcs7_get_chain;

use OpenXPKI::Crypto::OpenSSL::Command;
use vars qw(@ISA);
@ISA = qw(OpenXPKI::Crypto::OpenSSL::Command);

=head1 Parameters

You must specify the SIGNER or the SIGNER_SUBJECT.

=over

=item * PKCS7 (a signature)

=item * USE_ENGINE (optional)

=item * SIGNER (the signer to find the chain's begin)

=item * SIGNER_SUBJECT (the subject of the signer's certificate)

=back

=cut

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->{PKCS7FILE} = $self->{TMP}."/${$}_pkcs7.pem";
    $self->{CLEANUP}->{FILE}->{PKCS7} = $self->{PKCS7FILE};
    $self->{OUTFILE} = $self->{TMP}."/${$}_out.pem";
    $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};

    my $engine = "";
       $engine = $self->{ENGINE}->get_engine()
           if ($self->{USE_ENGINE} and $self->{ENGINE}->get_engine());

    ## check parameters

    if (not $self->{SIGNER})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_MISSING_SIGNER");
        return undef;
    }
    if (not $self->{PKCS7})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_MISSING_PKCS7");
        return undef;
    }

    ## prepare data

    return undef
        if (not $self->write_file (FILENAME => $self->{PKCS7FILE},
                                   CONTENT  => $self->{PKCS7}));

    ## build the command

    my $command  = "pkcs7 -print_certs";
    $command .= " -inform PEM";
    $command .= " -in ".$self->{PKCS7FILE};
    $command .= " -out ".$self->{OUTFILE};

    return [ $command ];
}

sub hide_output
{
    return 0;
}

## please notice that key_usage means usage of the engine's key
sub key_usage
{
    my $self = shift;
    return 0 if (exists $self->{CLEANUP}->{ENV}->{PWD});
    return 1;
}

sub get_result
{
    my $self = shift;

    my $pkcs7 = $self->read_file ($self->{OUTFILE});
    if ($pkcs7)
    {
        ## split certs
        my %certs = ();
        my @parts = split /\n\n/, $pkcs7;
        foreach my $cert (@parts)
        {
            my ($subject, $issuer) = ($cert, $cert);
            $subject =~ s/^subject=([^\n]*)\n.*/$1/s;
            $issuer  =~ s/^.*\nissuer=([^\n]*)\n.*/$1/s;
            $cert    =~ s/^.*\n-----BEGIN/-----BEGIN/s;
            $certs{$subject}->{ISSUER} = $issuer;
            $certs{$subject}->{CERT}   = $cert;
        }
        
        ## order certs
        my $subject = $self->{SIGNER_SUBJECT};
        if (not $subject)
        {
            my $x509 = $self->{ENGINE}->get_object (DATA => $self->{SIGNER},
                                                    TYPE => "X509");
            if (not $x509)
            {
                $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_WRONG_SIGNER",
                                  "__ERRVAL__", $self->{TOKEN}->errval());
                return undef;
            }
            $subject = $x509->openssl_subject();
            $x509->free();
        }
        $pkcs7 = "";
        while (exists $certs{$subject})
        {
            $pkcs7  .= $certs{$subject}->{CERT}."\n\n";
            last if ($subject eq $certs{$subject}->{ISSUER});
            $subject = $certs{$subject}->{ISSUER};
        }
        return $pkcs7;
    } else {
        return undef;
    }
}

1;
