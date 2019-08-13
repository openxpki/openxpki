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

=back

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

returns the signer on success
