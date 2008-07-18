## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_verify
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## changes for CHAIN passing by Alexander Klink for the OpenXPKI
## project 2006.
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_verify;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

use Data::Dumper;

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->get_tmpfile ('CONTENT', 'PKCS7', 'CHAIN', 'OUT');

    my $engine = "";
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $engine = $self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            ($engine_usage =~ m{ ALWAYS }xms));

# we do not want chains in tokens any longer
#    $self->{CHAIN} = $self->{ENGINE}->get_chainfile()
#       if (not $self->{CHAIN} and $self->{ENGINE}->get_chainfile());

    if (! defined $self->{CHAIN}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_VERIFY_MISSING_CHAIN',
        );
    }

    ## check parameters

    if (not $self->{CONTENT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_VERIFY_MISSING_CONTENT");
    }
    if (not $self->{PKCS7})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_VERIFY_MISSING_PKCS7");
    }

    ## prepare data

    my $chain = join('', @{$self->{CHAIN}});

    $self->write_file(
        FILENAME => $self->{CHAINFILE},
        CONTENT  => $chain,
        FORCE    => 1,
    );

    $self->write_file (FILENAME => $self->{CONTENTFILE},
                       CONTENT  => $self->{CONTENT},
	               FORCE    => 1);
    $self->write_file (FILENAME => $self->{PKCS7FILE},
                       CONTENT  => $self->{PKCS7},
	               FORCE    => 1);

    ## build the command

    my $command  = "smime -verify";
    $command .= " -inform PEM";
    $command .= " -content ".$self->{CONTENTFILE};
    $command .= " -in ".$self->{PKCS7FILE};
    $command .= " -noverify" if ($self->{NO_VERIFY});
    $command .= " -engine $engine" if ($engine);
    $command .= " -CAfile ".$self->{CHAINFILE};
    $command .= " -signer ".$self->{OUTFILE};

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
    return 0;
}

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
    ## this is the content !!!

    #my $pkcs7 = $self->read_file ($self->{OUTFILE});
    #if ($pkcs7 eq $self->{CONTENT})
    #{
    #    return 1;
    #} else {
    #    return undef;
    #}
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_verify

=head1 Functions

=head2 get_command

=over

=item * CONTENT (original data which was signed)

=item * PKCS7 (signature which should be verified)

=item * ENGINE_USAGE

=item * CHAIN

is an array of PEM encoded certificates

=item * NO_VERIFY (do not check the signer certificate)

=back

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

returns the signer on success
