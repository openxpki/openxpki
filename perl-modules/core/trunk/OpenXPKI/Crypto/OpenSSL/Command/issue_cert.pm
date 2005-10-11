## OpenXPKI::Crypto::OpenSSL::Command::issue_cert
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Command::issue_cert;

use base qw(OpenXPKI::Crypto::OpenSSL::Command);

use Math::BigInt;

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->{CSRFILE} = $self->{TMP}."/${$}_csr.pem";
    $self->{CLEANUP}->{FILE}->{CSR} = $self->{CSRFILE};
    $self->{OUTFILE} = $self->{TMP}."/${$}_cert.pem";
    $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};

    ## ENGINE key's cert: no parameters
    ## normal cert: engine (optional), passwd, key

    my ($engine, $keyform, $passwd, $key) = ("", "", undef);
    $engine  = $self->{ENGINE}->get_engine();
    $keyform = $self->{ENGINE}->get_keyform();
    $passwd  = $self->{ENGINE}->get_passwd();
    $self->{KEYFILE} = $self->{ENGINE}->get_keyfile();

    my $subject = undef;
    if (exists $self->{SUBJECT} and length ($self->{SUBJECT}))
    {
        ## fix DN-handling of OpenSSL
        $subject = $self->__get_openssl_dn ($self->{SUBJECT});
    }

    ## check parameters

    if (not $self->{KEYFILE} or not -e $self->{KEYFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_MISSING_KEYFILE");
    }
    if (not $self->{CSR})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_MISSING_CSRFILE");
    }
    if (not $self->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_MISSING_CONFIG");
    }
    if (exists $self->{DAYS} and
        ($self->{DAYS} !~ /\d+/ or $self->{DAYS} <= 0))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_WRONG_DAYS");
    }
    if (exists $self->{START} and
        ($self->{START} !~ /\d+/ or $self->{START} <= 0))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_WRONG_START");
    }
    if (exists $self->{END} and
        ($self->{END} !~ /\d+/ or $self->{END} <= 0))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_WRONG_END");
    }

    ## prepare data

    $self->write_file (FILENAME => $self->{CSRFILE},
                       CONTENT  => $self->{CSR});
    my $spkac = 0;
    if ($self->{CSR} !~ /^-----BEGIN/s and
        $self->{CSR} =~ /\nSPKAC\s*=/s)
    {
        $spkac = 1;
    }

    ## create serial, index and index attribute file

    my $config = $self->read_file ($self->{CONFIG});
    my $database = $self->__get_config_variable (NAME => "database", CONFIG => $config);
    my $serial   = $self->__get_config_variable (NAME => "serial", CONFIG => $config);

    $self->{SERIAL} = Math::BigInt->new ($self->{SERIAL});
    if (not $self->{SERIAL})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_FAILED_SERIAL");
    }
    my $hex    = substr ($self->{SERIAL}->as_hex(), 2);
    $hex       = "0".$hex if (length ($hex) % 2);

    $self->write_file (FILENAME => $database,
                       CONTENT  => "");
    $self->write_file (FILENAME => "$database.attr",
                       CONTENT  => "unique_subject = no\n");
    $self->write_file (FILENAME => $serial,
                       CONTENT  => $hex);
    $self->{CLEANUP}->{FILE}->{DATABASE}      = $database;
    $self->{CLEANUP}->{FILE}->{DATABASE_ATTR} = "$database.attr";
    $self->{CLEANUP}->{FILE}->{SERIAL}        = $serial;

    ## build the command

    my $command  = "ca -batch";
    $command .= " -config ".$self->{CONFIG};
    $command .= " -subj \"$subject\"" if ($subject);
    $command .= " -multivalue-rdn" if ($subject and $subject =~ /[^\\](\\\\)*\+/);
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -keyfile ".$self->{KEYFILE};
    $command .= " -cert ".$self->{ENGINE}->get_certfile();
    $command .= " -out ".$self->{OUTFILE};
    if ($spkac)
    {
        $command .= " -spkac ".$self->{CSRFILE};
    } else {
        $command .= " -in ".$self->{CSRFILE};
    }
    $command .= " -days ".$self->{DAYS} if (exists $self->{DAYS});
    $command .= " -startdate ".$self->{START} if (exists $self->{END});
    $command .= " -enddate ".$self->{START} if (exists $self->{END});
    $command .= " -preserveDN";

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
    my $result = $self->read_file ($self->{OUTFILE});
    $result =~ s/^.*-----BEGIN/-----BEGIN/s;
    return $result;
}

1;
__END__

=head1 Functions

=head2 get_command

=over

=item * SUBJECT (optional)

=item * CONFIG (optional)

=item * CSR

=item * SERIAL

=item * DAYS (optional)

=item * START (optional)

=item * END (optional)

=back

=head2 hide_output

return false

=head2 key_usage

return true

=head2 get_result

returns the new certificate
