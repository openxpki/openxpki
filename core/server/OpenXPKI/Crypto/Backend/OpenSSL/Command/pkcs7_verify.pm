package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_verify;
use OpenXPKI;

use parent qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    my $engine = "";
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $engine = $self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            ($engine_usage =~ m{ ALWAYS }xms));

    if (not $self->{PKCS7})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_VERIFY_MISSING_PKCS7");
    }

    # Assemble chain
    my $chainfile;
    if (defined $self->{CHAIN} ) {
        ## prepare data
        my $chain = join("\n", @{$self->{CHAIN}});
        $chainfile = $self->write_temp_file( $chain );

    # No chain is ok when no verify is given
    } elsif (!$self->{NO_CHAIN}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_VERIFY_MISSING_CHAIN',
        );
    }

    ## build the command

    my @command = qw( cms -verify -binary -inform PEM );
    push @command, ("-engine", $engine) if ($engine);
    push @command, ("-in", $self->write_temp_file( $self->{PKCS7} ));
    push @command, ("-signer", $self->get_outfile());

    # Optional parts
    if ($self->{CONTENT}) {
        push @command, ("-content", $self->write_temp_file( $self->{CONTENT} ));
    }

    push @command, ("-noverify") if ($self->{NO_CHAIN});

    if ($chainfile) {
        push @command, ("-CAfile",$chainfile);
    }

    if ($self->{CRL_CHECK}) {
        push @command, ($self->{CRL_CHECK} eq 'leaf' ? '-crl_check' : '-crl_check_all');
        OpenXPKI::Exception->throw (
            message => "CRL check requested but no CRL given"
        ) unless ($self->{CRL});
        push @command, ( '-CRLfile', $self->write_temp_file( $self->{CRL} ) );
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
    return 0;
}

#get_result moved to base class

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_verify

=head1 Functions

=head2 get_command

=over

=item * CONTENT (original data which was signed, optional)

=item * PKCS7 (signature which should be verified)

=item * ENGINE_USAGE

=item * CHAIN

is an array of PEM encoded certificates, mandatory unless NO_CHAIN is set

=item * NO_CHAIN (do not check the signer certificate)

=item * CRL

Must contain one or more PEM encoded CRLs.

Enables I<CRL_CHECK> with option 'all'.
If NOCHAIN is set, sets I<CRL_CHECK> to leaf


=item * CRL_CHECK

Set to I<leaf> to only validate the entity certificate.

=back

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

returns the signer on success
