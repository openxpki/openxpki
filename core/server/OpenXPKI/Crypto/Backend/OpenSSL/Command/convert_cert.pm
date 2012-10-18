## OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_cert
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## Enhanced to convert an array of certificates to PKCS#7
## 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_cert;
use OpenXPKI::Debug;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    my $container_format = 'X509';
    if (exists $self->{CONTAINER_FORMAT}) {
        $container_format = $self->{CONTAINER_FORMAT};
    }

    ##! 4: "get_command"
    if (not exists $self->{OUT})
    {
        OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CERT_MISSING_OUTPUT_FORMAT");
    }

    if ($container_format eq 'X509') {
        ##! 8: "DER or TXT"
        $self->get_tmpfile ('IN', 'OUT');
        $self->write_file (FILENAME => $self->{INFILE},
                CONTENT  => $self->{DATA},
                FORCE    => 1);

        ## check parameters

        if (not exists $self->{DATA})
        {
            OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CERT_MISSING_DATA");
        }
        ##! 16: "DATA is present"
        if (ref $self->{DATA} ne '') { # anything different from a scalar is
                                       # wrong here
            OpenXPKI::Exception->throw({
                message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CERT_WRONG_DATATYPE',
            });
        }
        ##! 16: "DATA is scalar"
        ## build the command

        my $inform = 'PEM';
        if (exists $self->{IN}) {
            $inform = $self->{IN};
        }

        my $command  = "x509";

        ## option '-engine' is needed here for correct cert convertion 
        ## in a case when engine introduces new crypto algorithms (like GOST ones), 
        ## which are not available in a classical OpenSSL library 
        my $engine_usage = $self->{ENGINE}->get_engine_usage();
        $command .= " -engine ".$self->{ENGINE}->get_engine()
            if ($self->{ENGINE}->get_engine() and
                    ($engine_usage =~ m{ NEW_ALG }xms));

        $command .= " -out ".$self->{OUTFILE};
        $command .= " -in ".$self->{INFILE};
        $command .= " -inform " . $inform;

        if ($self->{OUT} eq "DER") {
            $command .= " -outform DER";
        }
        elsif ($self->{OUT} eq "PEM") {
            $command .= " -outform PEM";
        }
        else {
            $command .= " -noout -text -nameopt RFC2253,-esc_msb";
        }
        ##! 8: "command: $command"
        return [ $command ];
    }
    elsif ($container_format eq 'PKCS7') { # convert array of certs to PKCS7
        # anything else than an array is wrong here
        ##! 4: "PKCS7"
        if (ref $self->{DATA} ne 'ARRAY') {
            OpenXPKI::Exception->throw({
                message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CERT_WRONG_DATATYPE',
            });
        }
        my @certs = @{$self->{DATA}};
        my $command = 'crl2pkcs7 -nocrl';
        if ($self->{OUT} eq 'DER')
        {
            $command .= ' -outform DER ';
        } 
        elsif ($self->{OUT} eq 'PEM') {
            $command .= ' -outform PEM ';
        }
        else {
            $command .= ' -noout -text -nameopt RFC2253,-esc_msb ';
        }
        $self->{OUTFILE} = $self->get_tmpfile();
        $command .= "-out $self->{OUTFILE} ";
        ##! 4: "before foreach"
        foreach my $cert (@certs) {
            ##! 8: $cert
            ## get each cert, write it to a temporary file and add the
            # corresponding part to the command
            my $filename = $self->get_tmpfile();
            ##! 8: "filename: $filename"
            $command .= "-certfile $filename ";
            $self->write_file(
                FILENAME => $filename,
                CONTENT  => $cert,
                FORCE    => 1,
            );
        }
        ##! 8: "command: $command"
        return [ $command ];
    }
    else {
        OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CERT_ILLEGAL_CONTAINER_FORMAT",
                params => {
                    CONTAINER_FORMAT => $container_format,
                },
                );
    }
}

sub hide_output
{
    return 0;
}

sub key_usage
{
    return 0;
}

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_cert

=head1 Functions

=head2 get_command

=over

=item * DATA

=item * IN (DER, PEM)

=item * OUT (DER, PEM, TXT)

=item * CONTAINER_FORMAT (X509, PKCS7)

=back

=head2 hide_output

returns 0

=head2 key_usage

returns 0

=head2 get_result

simply returns the converted certificate

