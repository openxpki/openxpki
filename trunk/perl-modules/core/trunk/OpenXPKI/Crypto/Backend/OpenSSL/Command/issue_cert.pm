## OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_cert
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_cert;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

use Math::BigInt;

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    if (not $self->{PROFILE} or
        not ref $self->{PROFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_MISSING_PROFILE");
    }
    my $profile = $self->{PROFILE};

    $self->get_tmpfile ('CSR',      'OUT');

    ## ENGINE key's cert: no parameters
    ## normal cert: engine (optional), passwd, key

    my ($engine, $keyform, $passwd, $key) = ("", "", undef);
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $engine  = $self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            (($engine_usage =~ /ALWAYS/i) or
             ($engine_usage =~ /PRIV_KEY_OPS/i)));
    $keyform = $self->{ENGINE}->get_keyform();
    $passwd  = $self->{ENGINE}->get_passwd();
    $self->{KEYFILE} = $self->{ENGINE}->get_keyfile();

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

    ## prepare data

    $self->write_config ($profile);
    $self->write_file (FILENAME => $self->{CSRFILE},
                       CONTENT  => $self->{CSR},
	               FORCE    => 1);
    my $spkac = 0;
    if ($self->{CSR} !~ /^-----BEGIN/s and
        $self->{CSR} =~ /\nSPKAC\s*=/s)
    {
        $spkac = 1;
    }

    ## build the command

    my $command  = "ca -batch";
    $command .= " -config ".$self->{CONFIGFILE};
    ## fix DN-handling of OpenSSL
    $command .= ' -subj "'.$self->get_openssl_dn($profile->get_subject()).'"';
    $command .= " -multivalue-rdn" if ($profile->get_subject() =~ /[^\\](\\\\)*\+/);
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -out ".$self->{OUTFILE};
    if ($spkac)
    {
        $command .= " -spkac ".$self->{CSRFILE};
    } else {
        $command .= " -in ".$self->{CSRFILE};
    }

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
    my $result = $self->read_file ($self->{OUTFILE});
    $result =~ s/^.*-----BEGIN/-----BEGIN/s;
    return $result;
}

1;
__END__

=head1 Functions

=head2 get_command

=over

=item * PROFILE

=item * CSR

=back

=head2 hide_output

return false

=head2 key_usage

return true

=head2 get_result

returns the new certificate
