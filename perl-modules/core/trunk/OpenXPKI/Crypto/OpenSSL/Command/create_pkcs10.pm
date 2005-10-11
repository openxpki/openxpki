## OpenXPKI::Crypto::OpenSSL::Command::create_pkcs10
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::create_pkcs10;

use base qw(OpenXPKI::Crypto::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    ## ENGINE key's CSR: no parameters
    ## normal CSR: engine (optional), passwd, key

    my ($engine, $keyform, $passwd, $key) = ("", "", undef);
    if ($self->{PASSWD} or $self->{KEY})
    {
        ## external CSR generation

        # check minimum requirements
        if (not exists $self->{PASSWD})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS10_MISSING_PASSWD");
        }
        if (not exists $self->{KEY})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS10_MISSING_KEY");
        }

        # prepare parameters
        $passwd = $self->{PASSWD};
        $engine = $self->{ENGINE}->get_engine() if ($self->{USE_ENGINE});
        $self->{KEYFILE} = $self->{TMP}."/${$}_key.pem";
        $self->{CLEANUP}->{FILE}->{KEY} = $self->{KEYFILE};
        $self->write_file (FILENAME => $self->{KEYFILE},
                           CONTENT  => $self->{KEY});
    } else {
        ## token CSR generation
        $engine  = $self->{ENGINE}->get_engine();
        $keyform = $self->{ENGINE}->get_keyform();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{KEYFILE} = $self->{ENGINE}->get_keyfile();
    }
    $self->{OUTFILE} = $self->{TMP}."/${$}_csr.pem";
    $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};


    ## check parameters

    if (not exists $self->{SUBJECT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS10_MISSING_SUBJECT");
    }
    if (not $self->{KEYFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS10_MISSING_KEYFILE");
    }
    if (not $self->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_PKCS10_MISSING_CONFIG");
    }

    ## prepare data

    ## fix DN-handling of OpenSSL
    my $subject = $self->__get_openssl_dn ($self->{SUBJECT});

    ## build the command

    my $command  = "req -new";
    $command .= " -config ".$self->{CONFIG};
    $command .= " -subj \"$subject\"";
    $command .= " -multivalue-rdn" if ($subject =~ /[^\\](\\\\)*\+/);
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -key ".$self->{KEYFILE};
    $command .= " -out ".$self->{OUTFILE};

    if (defined $passwd)
    {
        $command .= " -passin env:pwd";
	$ENV{'pwd'} = $passwd;
        $self->{CLEANUP}->{ENV}->{PWD} = "pwd";
    }

    return [ $command ];
}

sub hide_output
{
    return 0;
}

sub key_usage
{
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

If you want to create a csr for the used engine then you have
only to specify the SUBJECT and the CONFIG.

If you want to create a normal CSR then you must specify at minimum
a KEY and a PASSWD. If you want to use the engine then you must use
USE_ENGINE too.

=over

=item * SUBJECT

=item * CONFIG

=item * KEY

=item * USE_ENGINE

=item * PASSWD

=back

=head2 hide_output

returns false

=head2 key_usage

Returns true if the request is created for the engine's key.
Otherwise returns false.

=head2 get_result

Returns the newly created PEM encoded PKCS#10 key.
