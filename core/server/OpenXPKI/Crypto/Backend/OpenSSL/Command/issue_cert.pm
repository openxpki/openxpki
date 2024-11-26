package OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_cert;
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
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_MISSING_PROFILE");
    }
    $self->{CONFIG}->set_profile($self->{PROFILE});
    my $profile = $self->{PROFILE};



    ## ENGINE key's cert: no parameters
    ## normal cert: engine (optional), passwd, key

    my ($engine, $keyform, $passwd, $key) = ("", "", undef);
    my $engine_usage = $self->{ENGINE}->get_engine_usage();

    if ($self->{ENGINE}->get_engine() and
        (($engine_usage =~ m{ ALWAYS }xms) or ($engine_usage =~ m{ PRIV_KEY_OPS }xms))) {
            $engine  = $self->{ENGINE}->get_engine();
    }

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
    if ($key_store ne 'ENGINE' && not -e $self->{KEYFILE}) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_KEYFILE_DOES_NOT_EXIST",
                params => {
                    KEYFILE => $self->{KEYFILE}
                });
    }
    if (not $self->{CSR})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_ISSUE_CERT_MISSING_CSRFILE");
    }

    ## build the command

    my @command = qw( ca -batch );
    if ($self->{ENGINE}->get_engine() eq "pkcs11" and
        (ref $self->{ENGINE}) =~ m{^OpenXPKI::Crypto::Backend::OpenSSL::Engine::SafeNetProtectServer$}xms)
    {
        ## The OpenSSL patch for the SafeNet ProtectServer requires
        ## that the option -keyfile is used.
        push @command, ('-keyfile', $self->{KEYFILE});
    }
    push @command, (
        '-subj',
        $self->get_openssl_dn($profile->get_subject()),
    );
    push @command, '-multivalue-rdn' if ($profile->get_subject() =~ /[^\\](\\\\)*\+/);
    push @command, ('-engine', $engine) if ($engine);
    push @command, ('-keyform', $keyform) if ($keyform);
    push @command, ('-out', $self->get_outfile());
    push @command, ('-in', $self->write_temp_file( $self->{CSR}) );

    # Support for PSS Padding, see #811
    if (my $padding = $profile->get_padding()) {
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

sub get_result
{
    my $self = shift;
    my $result = $self->{FU}->read_file ($self->get_outfile());
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
