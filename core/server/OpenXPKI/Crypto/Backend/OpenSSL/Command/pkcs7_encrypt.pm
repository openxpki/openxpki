## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_encrypt
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_encrypt;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->get_tmpfile ('CONTENT', 'OUT');

    my $engine = "";
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $engine = $self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            ($engine_usage =~ m{ ALWAYS }xms));

    $self->{ENC_ALG}  = "aes256" if (not exists $self->{ENC_ALG});

    if ($self->{CERT})
    {
        $self->get_tmpfile ('CERT');
        $self->write_file (FILENAME => $self->{CERTFILE},
                           CONTENT  => $self->{CERT},
	                   FORCE    => 1);
    } else {
        $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
    }

    ## check parameters

    if (not $self->{CONTENT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_ENCRYPT_MISSING_CONTENT");
    }
    if (not $self->{CERT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_ENCRYPT_MISSING_CERT");
    }
    if ($self->{ENC_ALG} ne "aes256" and
        $self->{ENC_ALG} ne "aes192" and
        $self->{ENC_ALG} ne "aes128" and
        $self->{ENC_ALG} ne "idea" and
        $self->{ENC_ALG} ne "des3" and
        $self->{ENC_ALG} ne "des")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_ENCRYPT_WRONG_ENC_ALG");
    }

    ## prepare data

    $self->write_file (FILENAME => $self->{CONTENTFILE},
                       CONTENT  => $self->{CONTENT},
	               FORCE    => 1);

    ## build the command

    my $command  = "smime -encrypt";
    $command .= " -engine $engine" if ($engine);
    $command .= " -in ".$self->{CONTENTFILE};
    $command .= " -out ".$self->{OUTFILE};
    $command .= " -outform PEM";
    $command .= " -".$self->{ENC_ALG};
    $command .= " ".$self->{CERTFILE};

    return [ $command ];
}

sub hide_output
{
    return 1;
}

## please notice that key_usage means usage of the engine's key
sub key_usage
{
    my $self = shift;
    return 1;
}

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_encrypt

=head1 Functions

=head2 get_command

=over

=item * CONTENT

=item * ENGINE_USAGE

=item * CERT (optional)

=item * ENC_ALG (optional)

=back

=head2 hide_output

returns true

=head2 key_usage

returns true

=head2 get_result

returns the encrypted data
