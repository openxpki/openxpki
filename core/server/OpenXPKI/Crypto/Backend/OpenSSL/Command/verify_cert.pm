## OpenXPKI::Crypto::Backend::OpenSSL::Command::verify_cert
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

use OpenXPKI::Debug;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::verify_cert;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    if (!$self->{CERTIFICATE}) {
        OpenXPKI::Exception->throw (
            message =>
                "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_VERIFY_CERT_MISSING_CERTIFICATE",
        );
    }

    if (!$self->{TRUSTED}) {
        OpenXPKI::Exception->throw (
            message =>
                "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_VERIFY_CERT_MISSING_CERTIFICATE",
        );
    }

    $self->get_tmpfile ('CERTIFICATE', 'CHAIN', 'TRUSTED');

    $self->write_file (FILENAME => $self->{CERTIFICATEFILE},
            CONTENT  => $self->{CERTIFICATE},
            FORCE    => 1);

    $self->write_file (FILENAME => $self->{TRUSTEDFILE},
            CONTENT  => $self->{TRUSTED},
            FORCE    => 1);

    $self->write_file (FILENAME => $self->{CHAINFILE},
            CONTENT  => $self->{CHAIN},
            FORCE    => 1) if ($self->{CHAIN});

    ## build the command

    my @command = qw( verify );
    push @command, ('-CAfile', $self->{TRUSTEDFILE});
    push @command, ('-untrusted', $self->{CHAINFILE}) if ($self->{CHAIN});
    push @command, ( $self->{CERTIFICATEFILE} );

    ##! 32: 'SSL verify command ' . join " ", @command

    return [ \@command ];

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
    my $self   = shift;
    my $result = shift;

    ##! 16: 'openssl return ' . $result

    if ($result =~ /: OK/) {
        return 1;
    } else {
        return undef;
    }
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::verify_cert

=head1 Functions

=head2 get_command

Check if the set of entity, chain and ca certificate build a valid signature chain (calls openssl verify).

=over

=item CERTIFICATE

=item CHAIN

=item TRUSTED

=back

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

Returns 1 if verify is ok, undef if not.
