## OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_cert
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_cert;

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
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CERT_MISSING_DATA");
    }
    if (not exists $self->{OUT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CERT_MISSING_OUTPUT_FORMAT");
    }
    if ($self->{OUT} ne "DER" and $self->{OUT} ne "TXT")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CONVERT_CERT_WRONG_OUTPUT_FORMAT");
    }

    ## build the command

    my $command  = "x509";

    ## option '-engine' is needed here for correct cert convertion 
    ## in a case when engine introduces new crypto algorithms (like GOST ones), 
    ## which are not available in a classical OpenSSL library 
    $command .= " -engine ".$self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            ($self->{ENGINE}->{ENGINE_USAGE} =~ /NEW_ALG/i));

    $command .= " -out ".$self->{OUTFILE};
    $command .= " -in ".$self->{INFILE};
    if ($self->{OUT} eq "DER")
    {
        $command .= " -outform DER";
    } else {
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

simply returns the converted certificate

