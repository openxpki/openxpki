package OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_crl;
use OpenXPKI;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    if (not $self->{PROFILE} or
        not ref $self->{PROFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_MISSING_PROFILE");
    }
    $self->{CONFIG}->set_profile($self->{PROFILE});

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
    $self->{KEYFILE}  = $self->{ENGINE}->get_keyfile();
    #this is now in the openssl config
    #$self->{CERTFILE} = $self->{ENGINE}->get_certfile();

    ## check parameters

    if (not $self->{KEYFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_MISSING_KEYFILE");
    }
    my $key_store = $self->{ENGINE}->get_key_store();
    if ($key_store ne 'ENGINE' && not -e $self->{KEYFILE}) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CRL_KEYFILE_DOES_NOT_EXIST",
                params => { KEYFILE => $self->{KEYFILE} });
    }

    ## prepare data

    # new format, expect array with serial, reason code and revocation date
    if ($self->{CERTLIST}) {

        $self->{CONFIG}->set_crl_items($self->{CERTLIST});

    } elsif ($self->{REVOKED}) {
        OpenXPKI::Exception->throw (
            message => 'Deprecated call to issue_crl command using REVOKED - use CERTLIST'
        );
     }

    ## build the command

    my @command  = ('ca','-gencrl');
    push @command, '-engine', $engine if ($engine);

    if ($self->{ENGINE}->get_engine() eq "pkcs11" and
        (ref $self->{ENGINE}) =~ m{^OpenXPKI::Crypto::Backend::OpenSSL::Engine::SafeNetProtectServer$}xms)
    {
        ## The OpenSSL patch for the SafeNet ProtectServer requires
        ## that the option -keyfile is used.
        push @command, '-keyfile', $self->{KEYFILE};
    }

    push @command, '-keyform', $keyform if ($keyform);
    push @command, '-out', $self->get_outfile();

     # Support for PSS Padding, see #811
    if (my $padding = $self->{PROFILE}->get_padding()) {
        # shortcut - scalar value to use defaults
        if (ref $padding ne 'HASH') { $padding->{mode} = $padding // 'pkcs1' };
        # nothing to do yet

        if ($padding->{mode} eq 'pss') {
            push @command, '-sigopt', 'rsa_padding_mode:pss';
            push @command, '-sigopt', sprintf('rsa_pss_saltlen:%s', $padding->{saltlen} // '32');
            push @command, '-sigopt', sprintf('rsa_mgf1_md:%s', $padding->{mgf1_digest} // 'sha256');
        } elsif ($padding->{mode} ne 'pkcs1') {
            OpenXPKI::Exception->throw (message => "Unsupported padding mode " . $padding->{mode} );
        }
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

#get_result moved to base class

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_crl

=head1 Functions

=head2 get_command

=over

=item * SERIAL

=item * DAYS

=item * START

=item * ENC

=item * REVOKED

This parameter is an ARRAY reference. The elements of this array enumerate
all certificates to be placed on the CRL.

For details on the format of this parameter please refer to
OpenXPKI::Crypto::Backend::OpenSSL::Config::set_cert_list

=back

=head2 hide_output

returns false

=head2 key_usage

returns true

=head2 get_result

returns the new CRL
