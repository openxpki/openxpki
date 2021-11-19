## OpenXPKI::Crypto::Backend::OpenSSL::Command::decrypt_digest

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::decrypt_digest;

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
        $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();

    } elsif ( $self->{PASSWD} or $self->{KEY} ) {
        # external signature with provided key

        # check minimum requirements
        if ( not exists $self->{PASSWD} ) {
            OpenXPKI::Exception->throw( message =>
                "No password given to decrypt_digest"
            );
        }
        if ( not exists $self->{KEY} ) {
            OpenXPKI::Exception->throw( message =>
                "No key given to decrypt_digest"
            );
        }

        # prepare parameters
        $passwd = $self->{PASSWD};
        my $engine_usage = $self->{ENGINE}->get_engine_usage();
        $engine = $self->__get_used_engine();

        $self->{KEYFILE} = $self->write_temp_file( $self->{KEY} );

    } else {
        ## external signature with token key
        $engine           = $self->__get_used_engine();
        $passwd           = $self->{ENGINE}->get_passwd();
        $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
    }

    ## check parameters

    if ( not $self->{DATA} ) {
      OpenXPKI::Exception->throw( message => 'The data parameter is required for this operation' );
    }

    if ( not $self->{KEYFILE} ) {
        OpenXPKI::Exception->throw( message => 'A key is required for this operation' );
    }

    ## build the command

    my @command = qw( pkeyutl -decrypt );
    push @command, ("-inkey", $self->{KEYFILE});
    push @command, ('-engine', $engine) if ($engine);
    push @command, ('-keyform', $keyform) if ($keyform);

    push @command, ('-in', $self->write_temp_file( $self->{DATA} ));

    push @command, ('-out', $self->get_outfile());

    if ( defined $passwd ) {
        push @command, ('-passin','env:pwd');
        $self->set_env( 'pwd' => $passwd );
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
    return 1;
}

## please notice that key_usage means usage of the engine's key
sub key_usage {
    my $self = shift;
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::sign_digest

=head1 Functions

=head2 get_command

If you want to decrypt a digest with the used engine/token then you
have to specify only DATA (the binary value of the cipher text that
should be decrypted). If you want to use an external key you must
specify KEY and PASSWD.

If you want to use the engine then you must use ENGINE_USAGE ::=
ALWAYS||PRIV_KEY_OPS too.

=over

=item * DATA

=item * KEY

=item * PASSWD

=back

=head2 hide_output

returns false

=head2 key_usage

returns true

=head2 get_result

returns the raw decrypted data in binary format
