## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_decrypt
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_decrypt;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

use OpenXPKI::Debug;

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->get_tmpfile ('PKCS7', 'OUT');

    my ($engine, $passwd, $keyform);
    my $key_store = $self->{ENGINE}->get_key_store();
    ##! 16: 'token type: ' . $self->{TOKEN_TYPE}
    if ((   uc($self->{TOKEN_TYPE}) eq 'CA'
         || uc($self->{TOKEN_TYPE}) eq 'PASSWORD_SAFE'
        )
        && ($key_store eq 'ENGINE')) {
        ##! 16: 'token type ca or password_safe and keystore in engine'
        ## CA token signature
        $engine  = $self->{ENGINE}->get_engine();
        $keyform = $self->{ENGINE}->get_keyform();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
        $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
    }
    else {
        ## external signature
        if ($self->{PASSWD} or $self->{KEY})
        {
            ##! 16: 'external signature, key or password provided'
            ## user signature
            # check minimum requirements
            if (not exists $self->{PASSWD})
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_PASSWD");
            }
            if (not exists $self->{KEY})
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_KEY");
            }
            if (not exists $self->{CERT})
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_CERT");
            }

            # prepare parameters

            $passwd = $self->{PASSWD};
            $engine = $self->__get_used_engine();

            $self->get_tmpfile ('KEY', 'CERT');
            $self->write_file (FILENAME => $self->{KEYFILE},
                               CONTENT  => $self->{KEY},
	                       FORCE    => 1);

            $self->write_file (FILENAME => $self->{CERTFILE},
                               CONTENT  => $self->{CERT},
	                       FORCE    => 1);
        } else {
            ##! 16: 'external signature, token type ca or password_safe'
            if (   uc($self->{TOKEN_TYPE}) eq 'CA'
                || uc($self->{TOKEN_TYPE}) eq 'PASSWORD_SAFE') {
                ## CA external signature
                $engine  = $self->__get_used_engine();
                ##! 16: 'engine: ' . $engine
                $passwd  = $self->{ENGINE}->get_passwd();
                ##! 16: 'password: ' . $passwd
                $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
                ##! 16: 'certfile: ' . $self->{CERTFILE}
                $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
                ##! 16: 'keyfile: ' . $self->{KEYFILE}
            }
            else {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_PASSWD_OR_KEY");
            }
        }
    }

    ## check parameters

    if (not $self->{PKCS7})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_PKCS7");
    }
    if (not $self->{CERTFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_CERTFILE");
    }
    if (not $self->{KEYFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_DECRYPT_MISSING_KEY");
    }

    ## prepare data

    $self->write_file (FILENAME => $self->{PKCS7FILE},
                       CONTENT  => $self->{PKCS7},
	               FORCE    => 1);

    ## build the command

    my $command  = "smime -decrypt";
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -inkey ".$self->{KEYFILE} if ($self->{KEYFILE});
    $command .= " -recip ".$self->{CERTFILE} if ($self->{CERTFILE});
    $command .= " -inform PEM";
    $command .= " -in ".$self->{PKCS7FILE};
    $command .= " -out ".$self->{OUTFILE};

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

OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_decrypt

=head1 Functions

=head2 get_command

If you want to decrypt a PKCS#7 structure with the used engine/token then you have
only to specify the PKCS7.

If you want to decrypt a normal PKCS#7 structure then you must specify at minimum
a CERT, a KEY and a PASSWD. If you want to use the engine then you must use
ENGINE_USAGE ::= ALWAYS||PRIV_KEY_OPS too.

=over

=item * PKCS7

=item * ENGINE_USAGE

=item * CERT

=item * KEY

=item * PASSWD

=back

=head2 hide_output

returns true (if something is encrypted then it is usually secret)

=head2 key_usage

returns true

=head2 get_result

returns the decrpyted data
