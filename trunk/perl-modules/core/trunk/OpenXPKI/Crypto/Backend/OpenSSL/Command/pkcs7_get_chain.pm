## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain;

use OpenXPKI::Debug 'OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain';
use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);
use English;

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->get_tmpfile ('PKCS7', 'OUT');

    my $engine = "";
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $engine = $self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            ($engine_usage =~ m{ ALWAYS }xms));

    ## check parameters

    if (not $self->{SIGNER})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_MISSING_SIGNER");
    }
    if (not $self->{PKCS7})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_MISSING_PKCS7");
    }

    ## prepare data

    $self->write_file (FILENAME => $self->{PKCS7FILE},
                       CONTENT  => $self->{PKCS7},
	               FORCE    => 1);

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
    return 0;
}

sub get_result
{
    my $self = shift;

    my $pkcs7 = $self->read_file ($self->{OUTFILE});
    ##! 2: "split certs"
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
    
    ##! 2: "order certs"
    my $subject = $self->{SIGNER_SUBJECT};
    if (not $subject)
    {
        ##! 4: "determine the subject of the end entity cert"
        eval
        {
            my $x509 = $self->{XS}->get_object ({DATA => $self->{SIGNER},
                                                     TYPE => "X509"});
            $subject = $self->{XS}->get_object_function ({
                           OBJECT   => $x509,
                           FUNCTION => "openssl_subject"});
            $self->{XS}->free_object ($x509);
        };
        ##! 4: "eval finished"
        if (my $exc = OpenXPKI::Exception->caught())
        {
            ##! 8: "OpenXPKI exception detected"
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_WRONG_SIGNER",
                child   => $exc);
        } elsif ($EVAL_ERROR) {
            ##! 8: "general exception detected"
            $EVAL_ERROR->rethrow();
        }
    }
    ##! 2: "create ordered cert list"
    $pkcs7 = "";
    while (exists $certs{$subject})
    {
        $pkcs7  .= $certs{$subject}->{CERT}."\n\n";
        last if ($subject eq $certs{$subject}->{ISSUER});
        $subject = $certs{$subject}->{ISSUER};
    }
    ##! 2: "end"
    return $pkcs7;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain

=head1 Functions

=head2 get_command

You must specify the SIGNER or the SIGNER_SUBJECT.

=over

=item * PKCS7 (a signature)

=item * ENGINE_USAGE

=item * SIGNER (the signer to find the chain's begin)

=item * SIGNER_SUBJECT (the subject of the signer's certificate)

=back

=head2 hide_output

returns false (chain verification is not a secret)

=head2 key_usage

returns false

=head2 get_result

Returns the PEM-encoded certificates in the correct order which are
contained in the signature. The certificates are seperated by a blank
line.
