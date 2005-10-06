## OpenXPKI::Crypto::OpenSSL::Command::pkcs7_verify
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::pkcs7_verify;

use base qw(OpenXPKI::Crypto::OpenSSL::Command);

=head1 Parameters

=over

=item * CONTENT (original data which was signed)

=item * PKCS7 (signature which should be verified)

=item * USE_ENGINE (optional)

=item * CHAIN (this must be a single file for security reasons!!!)

=item * NO_VERIFY (do not check the signer certificate)

=back

=cut

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->{CONTENTFILE} = $self->{TMP}."/${$}_content.pem";
    $self->{CLEANUP}->{FILE}->{CONTENT} = $self->{CONTENTFILE};
    $self->{PKCS7FILE} = $self->{TMP}."/${$}_pkcs7.pem";
    $self->{CLEANUP}->{FILE}->{PKCS7} = $self->{PKCS7FILE};
    $self->{OUTFILE} = $self->{TMP}."/${$}_out.pem";
    $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};

    my $engine = "";
       $engine = $self->{ENGINE}->get_engine()
           if ($self->{USE_ENGINE} and $self->{ENGINE}->get_engine());
    $self->{CHAIN} = $self->{ENGINE}->get_chainfile()
       if (not $self->{CHAIN} and $self->{ENGINE}->get_chainfile());

    ## check parameters

    if (not $self->{CONTENT})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_VERIFY_MISSING_CONTENT");
        return undef;
    }
    if (not $self->{PKCS7})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_VERIFY_MISSING_PKCS7");
        return undef;
    }

    ## prepare data

    return undef
        if (not $self->write_file (FILENAME => $self->{CONTENTFILE},
                                   CONTENT  => $self->{CONTENT}));
    return undef
        if (not $self->write_file (FILENAME => $self->{PKCS7FILE},
                                   CONTENT  => $self->{PKCS7}));

    ## build the command

    my $command  = "smime -verify";
    $command .= " -inform PEM";
    $command .= " -content ".$self->{CONTENTFILE};
    $command .= " -in ".$self->{PKCS7FILE};
    $command .= " -noverify" if ($self->{NO_VERIFY});
    $command .= " -engine $engine" if ($engine);
    $command .= " -CAfile ".$self->{CHAIN};
    $command .= " -signer ".$self->{OUTFILE};

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
    return $self->read_file ($self->{OUTFILE});
    ## this is the content !!!

    #my $pkcs7 = $self->read_file ($self->{OUTFILE});
    #if ($pkcs7 eq $self->{CONTENT})
    #{
    #    return 1;
    #} else {
    #    return undef;
    #}
}

1;
