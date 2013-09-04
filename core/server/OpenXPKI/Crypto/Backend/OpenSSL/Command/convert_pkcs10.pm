## OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkcs10
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkcs10;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    $self->get_tmpfile ('IN', 'OUT');
    $self->write_file (FILENAME => $self->{INFILE},
                       CONTENT  => $self->{DATA},
	               FORCE    => 1);

    ## check parameters

    if (not exists $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_MISSING_DATA");
    }
    if (! exists $self->{IN}) {
        # default input format is PEM
        $self->{IN} = 'PEM';
    }
    if ($self->{IN} ne 'PEM' && $self->{IN} ne 'DER') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_INCORRECT_INPUT_FORMAT',
            params  => {
                FORMAT => $self->{IN},
            },
        );
    }
    if (not exists $self->{OUT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_MISSING_OUTPUT_FORMAT");
    }
    if ($self->{OUT} ne "DER" && $self->{OUT} ne "TXT" && $self->{OUT} ne 'PEM')
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_PKCS10_WRONG_OUTPUT_FORMAT");
    }

    ## build the command

    my $command  = "req";

    ## option '-engine' is needed here for correct req convertion
    ## in a case when engine introduces new crypto algorithms (like GOST ones),
    ## which are not available in a classical OpenSSL library
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $command .= " -engine ".$self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            ($engine_usage =~ m{ NEW_ALG }xms));

    $command .= " -out ".$self->{OUTFILE};
    $command .= " -in ".$self->{INFILE};
    $command .= " -inform " . $self->{IN};
    if ($self->{OUT} eq "DER") {
        $command .= " -outform DER";
    }
    elsif ($self->{OUT} eq 'PEM') {
        $command .= " -outform PEM";
    }
    else {
        $command .= " -noout -text -nameopt RFC2253,-esc_msb";
    }

    return [ $command ];
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

OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkcs10

=head1 Functions

=head2 get_command

=over

=item * DATA

=item * OUT (DER, TXT)

=back

=head2 hide_output

returns 0

=head2 key_usage

returns 0

=head2 get_result

simply returns the converted CSR

