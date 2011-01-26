## OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_cert
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

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
    $self->{CONFIG}->set_profile($self->{PROFILE});
    my $profile = $self->{PROFILE};

    $self->get_tmpfile ('CSR',      'OUT');

    ## ENGINE key's cert: no parameters
    ## normal cert: engine (optional), passwd, key

    my ($engine, $keyform, $passwd, $key) = ("", "", undef);
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $engine  = $self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            (($engine_usage =~ m{ ALWAYS }xms) or
             ($engine_usage =~ m{ PRIV_KEY_OPS }xms)));
    $keyform = $self->{ENGINE}->get_keyform();
    $passwd  = $self->{ENGINE}->get_passwd();
    $self->{KEYFILE} = $self->{ENGINE}->get_keyfile();

    ## check parameters

    if (not $self->{KEYFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_MISSING_KEYFILE");
    }
    my $key_store = $self->{ENGINE}->get_key_store();
    if ( (uc($self->{TOKEN_TYPE}) ne 'CA') or ($key_store ne 'ENGINE'))
    {
        if (not -e $self->{KEYFILE})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_KEYFILE_DOES_NOT_EXIST");
        }
    }
    if (not $self->{CSR})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_MISSING_CSRFILE");
    }

    ## prepare data

    my $spkac = 0;
    if ($self->{CSR} !~ m{\A -----BEGIN }xms)
    {
        $spkac = 1;
        $self->{CSR} = 'SPKAC=' . $self->{CSR};
    }
    #done by CLI
    #$self->{CONFIG}->dump();
    #my $config = $self->{CONFIG}->get_config_filename();
    $self->write_file (FILENAME => $self->{CSRFILE},
                       CONTENT  => $self->{CSR},
	               FORCE    => 1);

    ## build the command

    my @command = qw( ca -batch );
    push @command, (
        '-subj',
        $self->get_openssl_dn($profile->get_subject()),
    );
    push @command, '-multivalue-rdn' if ($profile->get_subject() =~ /[^\\](\\\\)*\+/);
    push @command, ('-engine', $engine) if ($engine);
    push @command, ('-keyform', $keyform) if ($keyform);
    push @command, ('-out', $self->{OUTFILE});
    if ($spkac)
    {
        push @command, ('-spkac', $self->{CSRFILE});
    } else {
        push @command, ('-in', $self->{CSRFILE});
    }

    if (defined $passwd)
    {
        push @command, ('-passin', 'env:pwd');
        $self->set_env ("pwd" => $passwd);
    }

    return [ \@command ];
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

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_cert

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
