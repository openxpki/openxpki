## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_verify
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_verify;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->set_tmpfile ("CONTENT" => $self->{TMP}."/${$}_content.pem");
    $self->set_tmpfile ("PKCS7"   => $self->{TMP}."/${$}_pkcs7.pem");
    $self->set_tmpfile ("OUT"     => $self->{TMP}."/${$}_out.pem");

    my $engine = "";
       $engine = $self->{ENGINE}->get_engine()
           if ($self->{USE_ENGINE} and $self->{ENGINE}->get_engine());
    $self->{CHAIN} = $self->{ENGINE}->get_chainfile()
       if (not $self->{CHAIN} and $self->{ENGINE}->get_chainfile());

    ## check parameters

    if (not $self->{CONTENT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_VERIFY_MISSING_CONTENT");
    }
    if (not $self->{PKCS7})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_VERIFY_MISSING_PKCS7");
    }

    ## prepare data

    $self->write_file (FILENAME => $self->{CONTENTFILE},
                       CONTENT  => $self->{CONTENT});
    $self->write_file (FILENAME => $self->{PKCS7FILE},
                       CONTENT  => $self->{PKCS7});

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
    return 0;
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
__END__

=head1 Functions

=head2 get_command

=over

=item * CONTENT (original data which was signed)

=item * PKCS7 (signature which should be verified)

=item * USE_ENGINE (optional)

=item * CHAIN (this must be a single file for security reasons!!!)

=item * NO_VERIFY (do not check the signer certificate)

=back

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

returns the signer on success
