## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_sign
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_sign;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->get_tmpfile ('CONTENT', 'OUT');

    my ($engine, $passwd, $keyform);
    if ($self->{PASSWD} or $self->{KEY})
    {
        ## external signature

        # check minimum requirements
        if (not exists $self->{PASSWD})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_PASSWD");
        }
        if (not exists $self->{KEY})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_KEY");
        }
        if (not exists $self->{CERT})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_CERT");
        }

        # prepare parameters

        $passwd = $self->{PASSWD};
        $engine = $self->{ENGINE}->get_engine()
            if ($self->{ENGINE}->get_engine() and
                (($self->{ENGINE}->{ENGINE_USAGE} =~ /ALWAYS/i) or
                 ($self->{ENGINE}->{ENGINE_USAGE} =~ /PRIV_KEY_OPS/i)));

        $self->get_tmpfile ('KEY', 'CERT');
        $self->write_file (FILENAME => $self->{KEYFILE},
                           CONTENT  => $self->{KEY},
	                   FORCE    => 1);

        $self->write_file (FILENAME => $self->{CERTFILE},
                           CONTENT  => $self->{CERT},
	                   FORCE    => 1);
    } else {
        ## token signature
        $engine  = $self->{ENGINE}->get_engine();
        $keyform = $self->{ENGINE}->get_keyform();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
        $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
    }

    ## check parameters

    if (not $self->{CONTENT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_CONTENT");
    }
    if (not $self->{CERT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_CERT");
    }
    if (not $self->{KEY})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_KEY");
    }

    ## prepare data

    $self->write_file (FILENAME => $self->{CONTENTFILE},
                       CONTENT  => $self->{CONTENT},
	               FORCE    => 1);

    ## build the command

    my $command  = "smime -sign";
    $command .= " -nodetach" if (not $self->{DETACH});
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -inkey ".$self->{KEYFILE} if ($self->{KEYFILE});
    $command .= " -signer ".$self->{CERTFILE} if ($self->{CERTFILE});
    $command .= " -in ".$self->{CONTENTFILE};
    $command .= " -out ".$self->{OUTFILE};
    $command .= " -outform PEM";

    if (defined $passwd)
    {
        $command .= " -passin env:pwd";
        $self->set_env ("pwd" => $passwd);
    }

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
    return 1;
}

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}

1;
__END__

=head1 Functions

=head2 get_command

If you want to create a signature with the used engine/token then you have
only to specify the CONTENT.

If you want to create a normal signature then you must specify at minimum
a CERT, a KEY and a PASSWD. If you want to use the engine then you must use
ENGINE_USAGE ::= ALWAYS||PRIV_KEY_OPS too.

=over

=item * CONTENT

=item * ENGINE_USAGE

=item * CERT

=item * KEY

=item * PASSWD

=item * DETACH (strip off the content from the resulting PKCS#7 structure)

=back

=head2 hide_output

returns false

=head2 key_usage

returns true

=head2 get_result

returns the PKCS#7 signature in PEM format
