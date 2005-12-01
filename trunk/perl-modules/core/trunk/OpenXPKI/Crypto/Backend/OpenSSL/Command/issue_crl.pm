## OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_crl
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_crl;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

use Math::BigInt;
use English;

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->get_tmpfile ('OUT');

    ## ENGINE key's cert: no parameters
    ## normal cert: engine (optional), passwd, key

    my ($engine, $keyform, $passwd, $key) = ("", "", undef);
    $engine  = $self->{ENGINE}->get_engine();
    $keyform = $self->{ENGINE}->get_keyform();
    $passwd  = $self->{ENGINE}->get_passwd();
    $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
    $self->{CERTFILE} = $self->{ENGINE}->get_certfile();

    ## check parameters

    if (not $self->{KEYFILE} or not -e $self->{KEYFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_MISSING_KEYFILE");
    }
    if (not $self->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_MISSING_CONFIG");
    }
    if (exists $self->{DAYS} and
        ($self->{DAYS} !~ /\d+/ or $self->{DAYS} <= 0))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_WRONG_DAYS");
    }

    ## prepare data

    my $index_txt = "";
    if ($self->{REVOKED})
    {
        foreach my $arrayref (@{$self->{REVOKED}})
        {
            # end of time_t datatype in C library
            my ($cert, $timestamp) = (undef, "2038:01:16T23:59:59.9999999");
            if (not ref $arrayref)
            {
                $cert      = $arrayref;
            } else {
                $cert      = $arrayref->[0];
                $timestamp = $arrayref->[1]
                    if (scalar @{$arrayref} > 1);
            }
            # get X509 object
            if (not ref($cert))
            {
                eval {
                    $cert = $self->{ENGINE}->get_object(DATA => $cert, TYPE => "X509");
                };
                if (my $exc = OpenXPKI::Exception->caught())
                {
                    OpenXPKI::Exception->throw (
                        message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_REVOKED_CERT_FAILED",
                        child   => $exc);
                } elsif ($EVAL_ERROR) {
                    $EVAL_ERROR->rethrow();
                }
            }
            # prepare index.txt entry
            $timestamp = $self->get_openssl_time ($timestamp);
            my $start = $self->{ENGINE}->get_object_function (
                            OBJECT   => $cert,
                            FUNCTION => "notbefore");
            $start = $self->get_openssl_time ($start);
            my $subject = $self->{ENGINE}->get_object_function (
                              OBJECT   => $cert,
                              FUNCTION => "subject");
            $subject = $self->get_openssl_dn($subject);
            my $serial = $self->{ENGINE}->get_object_function (
                             OBJECT   => $cert,
                             FUNCTION => "serial");
            $serial = Math::BigInt->new ($serial);
            my $hex = substr ($serial->as_hex(), 2);
            $hex    = "0".$hex if (length ($hex) % 2);
            $index_txt = "R\t$start\t$timestamp\t$hex\tunknown\t$subject\n";
        }
    }

    ## create serial, index and index attribute file

    my $config = $self->read_file ($self->{CONFIG});
    my $database = $self->get_config_variable (NAME => "database", CONFIG => $config);
    my $serial   = $self->get_config_variable (NAME => "crlnumber", CONFIG => $config);

    if ($serial)
    {
        if (not exists $self->{SERIAL})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_MISSING_SERIAL");
        }
        $self->{SERIAL} = Math::BigInt->new ($self->{SERIAL});
        if (not $self->{SERIAL})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_FAILED_SERIAL");
        }
        my $hex    = substr ($self->{SERIAL}->as_hex(), 2);
        $hex       = "0".$hex if (length ($hex) % 2);
        $self->write_file (FILENAME => $serial,
                           CONTENT  => $hex);
        $self->set_tmpfile ("SERIAL" => $serial);
    }

    $self->write_file (FILENAME => $database,
                       CONTENT  => $index_txt);
    $self->write_file (FILENAME => "$database.attr",
                       CONTENT  => "unique_subject = no\n");
    $self->set_tmpfile ("DATABASE"      => $database);
    $self->set_tmpfile ("DATABASE_ATTR" => "$database.attr");

    ## build the command

    my $command  = "ca -gencrl";
    $command .= " -config ".$self->{CONFIG};
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -keyfile ".$self->{KEYFILE};
    $command .= " -cert ".$self->{ENGINE}->get_certfile();
    $command .= " -out ".$self->{OUTFILE};
    $command .= " -days ".$self->{DAYS} if (exists $self->{DAYS});

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

=over

=item * SERIAL

=item * DAYS

=item * START

=item * ENC

=item * REVOKED

This parameter is an ARRAY reference. The elements of this array
are an ARRAY too which contains the certificate and the timestamp. The
certificate can be a PEM encoded X.509v3 certificate or it must
be a reference to an OpenXPKI::Crypto::Backend::OpenSSL::X509 object. The
timestamp must be a timestamp which is automatically parseable
by Date::Parse.

=back

=head2 hide_output

returns false

=head2 key_usage

returns true

=head2 get_result

returns the new CRL
