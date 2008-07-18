## OpenXPKI::Crypto::Backend::OpenSSL::Command::get_pkcs8_keytype
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::get_pkcs8_keytype;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);
use OpenXPKI::Debug;

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    my $engine = "";
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    if ($self->{ENGINE}->get_engine() and 
        (($engine_usage =~ m{ NEW_ALG }xms) or 
         ($engine_usage =~ m{ ALWAYS }xms) or 
         ($engine_usage =~ m{ PRIV_KEY_OPS }xms))
       ) {
        $engine = $self->{ENGINE}->get_engine();
    }

    $self->get_tmpfile ('KEY', 'OUT');
    $self->write_file (FILENAME => $self->{KEYFILE},
                       CONTENT  => $self->{DATA},
	               FORCE    => 1);
    if (not exists $self->{PASSWD})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_GET_PKCS8_KEYTYPE_MISSING_PASSWD");
    }
    if (not exists $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_GET_PKCS8_KEYTYPE_MISSING_DATA");
    }

    ## build the command

    my $command  = "pkcs8 ";
    $command .= " -inform PEM";

    $command .= " -engine $engine" if ($engine);
    $command .= " -in ".$self->{KEYFILE};
    $command .= " -out ".$self->{OUTFILE};

    if ($self->{PASSWD})
    {
        $command .= " -passin env:pwd";
        $self->set_env ("pwd" => $self->{PASSWD});
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
    my $result = $self->read_file($self->{OUTFILE});
    my ($type) = ($result =~ m{ \A -----BEGIN\ ([A-Z]+)\ PRIVATE\ KEY----- }xms);
    ##! 16: 'type: ' . $type
    return $type;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::get_pkcs8_keytype

=head1 Description

This command returns the type of a key contained in a PKCS#8 PEM
data block. This is necessary if you want to convert a PKCS#8 to
an OpenSSL/SSLeay format, as you need to know the key type for that
so that the conversion can be done in one step.

=head1 Functions

=head2 get_command

=over

=item * DATA - the PKCS#8 PEM data

=item * PASSWD - the password for the PKCS#8

=back

=head2 hide_output

returns 1 

=head2 key_usage

returns 1 (private key must be decoded first)

=head2 get_result

simply returns the type, e.g. RSA, EC, DSA.

