## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_sign
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

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
    my $key_store = $self->{ENGINE}->get_key_store();
    if ((uc($self->{TOKEN_TYPE}) eq 'CA') and ($key_store eq 'ENGINE')) {
        ## CA token signature
        $engine  = $self->{ENGINE}->get_engine();
        $keyform = $self->{ENGINE}->get_keyform();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
        $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
    }
    else {  ## external signature
        if ($self->{PASSWD} or $self->{KEY})
        {
            ## user signature

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
            my $engine_usage = $self->{ENGINE}->get_engine_usage();
            $engine = $self->__get_used_engine(); 

            $self->get_tmpfile ('KEY', 'CERT');
            $self->write_file (FILENAME => $self->{KEYFILE},
                               CONTENT  => $self->{KEY},
	                       FORCE    => 1);

            $self->write_file (FILENAME => $self->{CERTFILE},
                               CONTENT  => $self->{CERT},
	                       FORCE    => 1);
        } else {
            if (uc($self->{TOKEN_TYPE}) eq 'CA') {
                ## CA external signature
                $engine  = $self->__get_used_engine();
                $passwd  = $self->{ENGINE}->get_passwd();
                $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
                $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
            }
            else {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_PASSWD_OR_KEY");
            } # if TOKEN_TYPE = 'CA'
        } # if PASSWD and KEY are not defined
    } # if signature is external

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
    if (not $self->{KEYFILE})
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

sub __get_used_engine
{
    my $self = shift;
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    if ($self->{ENGINE}->get_engine() and
        (($engine_usage =~ m{ ALWAYS }xms) or
         ($engine_usage =~ m{ PRIV_KEY_OPS }xms))) {
        return $self->{ENGINE}->get_engine();
    }
    else {
        return "";
    }
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

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_sign

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
