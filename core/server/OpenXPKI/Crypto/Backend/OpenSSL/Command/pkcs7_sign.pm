## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_sign
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_sign;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command {
    my $self = shift;

    ## compensate missing parameters

    my ( $engine, $passwd, $keyform );
    my $key_store = $self->{ENGINE}->get_key_store();
    if ( $key_store eq 'ENGINE' ) {
        ## signature using engine
        $engine           = $self->{ENGINE}->get_engine();
        $keyform          = $self->{ENGINE}->get_keyform();
        $passwd           = $self->{ENGINE}->get_passwd();
        $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
        $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();

    } elsif ( $self->{PASSWD} or $self->{KEY} ) {
        ## external signature wit provided key
        ## user signature

        # check minimum requirements
        if ( not exists $self->{PASSWD} ) {
            OpenXPKI::Exception->throw( message =>
                "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_PASSWD"
            );
        }
        if ( not exists $self->{KEY} ) {
            OpenXPKI::Exception->throw( message =>
                  "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_KEY"
            );
        }
        if ( not exists $self->{CERT} ) {
            OpenXPKI::Exception->throw( message =>
                  "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_CERT"
            );
        }

        # prepare parameters

        $passwd = $self->{PASSWD};
        my $engine_usage = $self->{ENGINE}->get_engine_usage();
        $engine = $self->__get_used_engine();

        $self->{KEYFILE} = $self->write_temp_file( $self->{KEY} );
        $self->{CERTFILE} = $self->write_temp_file( $self->{CERT} );

    } else {
        ## external signature with token key
        $engine           = $self->__get_used_engine();
        $passwd           = $self->{ENGINE}->get_passwd();
        $self->{CERTFILE} = $self->{ENGINE}->get_certfile();
        $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
    }

    ## check parameters

    if ( not $self->{CONTENT} ) {
      OpenXPKI::Exception->throw( message =>
            "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_CONTENT" );
    }
    if ( not $self->{CERTFILE} ) {
      OpenXPKI::Exception->throw( message =>
            "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_CERT" );
    }
    if ( not $self->{KEYFILE} ) {
      OpenXPKI::Exception->throw( message =>
            "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_SIGN_MISSING_KEY" );
    }


    ## build the command

    my @command = qw( cms -sign -binary -outform PEM );
    push @command, ("-nodetach") if ( not $self->{DETACH} );
    push @command, ("-engine", $engine) if ($engine);
    push @command, ("-keyform", $keyform) if ($keyform);

    push @command, ("-in", $self->write_temp_file( $self->{CONTENT} ));
    push @command, ("-inkey", $self->{KEYFILE}) if ( $self->{KEYFILE} );
    push @command, ("-signer",$self->{CERTFILE}) if ( $self->{CERTFILE} );

    push @command, ("-out", $self->get_outfile());

    if ( defined $passwd ) {
        push @command, ("-passin","env:pwd");
        $self->set_env( "pwd" => $passwd );
    }

    return [ \@command ];
}

sub __get_used_engine {
    my $self         = shift;
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    if (
        $self->{ENGINE}->get_engine()
        and (  ( $engine_usage =~ m{ ALWAYS }xms )
            or ( $engine_usage =~ m{ PRIV_KEY_OPS }xms ) )
      )
    {
        return $self->{ENGINE}->get_engine();
    }
    else {
        return "";
    }
}

sub hide_output {
    return 0;
}

## please notice that key_usage means usage of the engine's key
sub key_usage {
    my $self = shift;
    return 1;
}

sub get_result
{
    my $self = shift;
    my $result = $self->SUPER::get_result();

    $result =~ s/ (-----BEGIN\ [\w\s]*) CMS (----- [^-]+ -----END\ [\w\s]*) CMS (-----) /${1}PKCS7${2}PKCS7${3}/gmsx;

    return $result;
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
