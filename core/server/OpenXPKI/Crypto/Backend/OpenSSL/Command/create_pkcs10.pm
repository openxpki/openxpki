## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs10
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs10;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    ## ENGINE key's CSR: no parameters
    ## normal CSR: engine (optional), passwd, key

    my ($engine, $keyform, $passwd, $key) = ("", "", undef);

    ## user CSR generation

    # check minimum requirements
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS10_MISSING_PASSWD"
    ) unless $self->{PASSWD};

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS10_MISSING_KEY"
    ) unless $self->{KEY};

    # prepare parameters
    $passwd = $self->{PASSWD};
    $engine = $self->__get_used_engine();

    # if profile is set we have an extension section
    if ($self->{PROFILE}) {
        $self->{CONFIG}->set_profile($self->{PROFILE});

    }

    ## build the command
    my @command = qw( req -new );

    # subject from string via command line
    if ($self->{SUBJECT}) {
        ## fix DN-handling of OpenSSL
        my $subject = $self->get_openssl_dn ($self->{SUBJECT});
        push @command, ('-subj', $subject);
        push @command, '-multivalue-rdn' if ($subject =~ /[^\\](\\\\)*\+/);

    # will profile will provide DN via config?
    } elsif (!($self->{PROFILE} && $self->{PROFILE}->get_subject())) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS10_MISSING_SUBJECT");
    }

    push @command, ('-nameopt', 'utf8');
    push @command, ('-engine', $engine) if ($engine);
    push @command, ('-keyform', $keyform) if ($keyform);
    push @command, ('-key', $self->write_temp_file( $self->{KEY} ));
    push @command, ('-out', $self->get_outfile());

    if (defined $passwd)
    {
        push @command, ('-passin', 'env:pwd');
        $self->set_env ("pwd" => $passwd);
    }
    return [ \@command ];
}

sub __get_used_engine
{
    my $self = shift;
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    if ($self->{ENGINE}->get_engine() and
        ($engine_usage =~ m{ (ALWAYS|PRIV_KEY_OPS) }xms)) {
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

sub key_usage
{
    return 1;
}

#get_result moved to base class

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs10

=head1 Functions

=head2 get_command

If you want to create a csr for the used engine then you have
only to specify the SUBJECT and the CONFIG.

If you want to create a normal CSR then you must specify at minimum
a KEY and a PASSWD. If you want to use the engine then you must use
ENGINE_USAGE ::= ALWAYS||PRIV_KEY_OPS too.

=over

=item * SUBJECT

=item * KEY

=item * ENGINE_USAGE

=item * PASSWD

=back

=head2 hide_output

returns false

=head2 key_usage

Returns true if the request is created for the engine's key.
Otherwise returns false.

=head2 get_result

Returns the newly created PEM encoded PKCS#10 key.
