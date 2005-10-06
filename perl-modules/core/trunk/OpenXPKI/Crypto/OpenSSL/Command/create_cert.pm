## OpenXPKI::Crypto::OpenSSL::Command::create_cert
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::create_cert;

use base qw(OpenXPKI::Crypto::OpenSSL::Command);

=head1 Parameters

If you want to create a cert for the used engine then you have
only to specify the CSR and the CONFIG.

If you want to create a normal certificate then you must specify at minimum
a KEY and a PASSWD. If you want to use the engine then you must use
USE_ENGINE too.

=over

=item * SUBJECT (optional)

=item * CONFIG (optional)

=item * KEY (optional)

=item * CSR

=item * USE_ENGINE (optional)

=item * PASSWD (optional)

=item * DAYS (optional)

=back

=cut

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->{CSRFILE} = $self->{TMP}."/${$}_csr.pem";
    $self->{CLEANUP}->{FILE}->{CSR} = $self->{CSRFILE};

    ## ENGINE key's cert: no parameters
    ## normal cert: engine (optional), passwd, key

    my ($engine, $keyform, $passwd, $key) = ("", "", undef);
    if ($self->{PASSWD} or $self->{KEY})
    {
        ## external cert generation

        # check minimum requirements
        if (not exists $self->{PASSWD})
        {
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_MISSING_PASSWD");
            return undef;
        }
        if (not exists $self->{KEY})
        {
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_MISSING_KEY");
            return undef;
        }

        # prepare parameters
        $passwd = $self->{PASSWD};
        $engine = $self->{ENGINE}->get_engine() if ($self->{USE_ENGINE});
        $self->{KEYFILE} = $self->{TMP}."/${$}_key.pem";
        $self->{CLEANUP}->{FILE}->{KEY} = $self->{KEYFILE};
        return undef
            if (not $self->write_file (FILENAME => $self->{KEYFILE},
                                       CONTENT  => $self->{KEY}));
        $self->{OUTFILE} = $self->{TMP}."/${$}_cert.pem";
        $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};
    } else {
        ## token cert generation
        $engine  = $self->{ENGINE}->get_engine();
        $keyform = $self->{ENGINE}->get_keyform();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{OUTFILE} = $self->{ENGINE}->get_certfile();
        $self->{KEYFILE} = $self->{ENGINE}->get_keyfile();
    }
    my $subject = undef;
    if (exists $self->{SUBJECT} and length ($self->{SUBJECT}))
    {
        ## fix DN-handling of OpenSSL
        $subject = $self->__get_openssl_dn ($self->{SUBJECT});
        return undef if (not $subject);
    }

    ## check parameters

    if (not $self->{KEYFILE} or not -e $self->{KEYFILE})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_MISSING_KEYFILE");
        return undef;
    }
    if (not $self->{CSR})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_MISSING_CSRFILE");
        return undef;
    }
    if (not $self->{CONFIG})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_MISSING_CONFIG");
        return undef;
    }
    if (exists $self->{DAYS} and
        ($self->{DAYS} !~ /\d+/ or $self->{DAYS} <= 0))
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_WRONG_DAYS");
        return undef;
    }

    ## prepare data

    return undef
        if (not $self->write_file (FILENAME => $self->{CSRFILE},
                                   CONTENT  => $self->{CSR}));

    ## build the command

    my $command  = "req -x509";
    $command .= " -config ".$self->{CONFIG};
    $command .= " -subj \"$subject\"" if ($subject);
    $command .= " -multivalue-rdn" if ($subject and $subject =~ /[^\\](\\\\)*\+/);
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -key ".$self->{KEYFILE};
    $command .= " -out ".$self->{OUTFILE};
    $command .= " -in ".$self->{CSRFILE};
    $command .= " -days ".$self->{DAYS} if (exists $self->{DAYS});

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
}

1;
