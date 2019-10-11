## OpenXPKI::Crypto::Backend::OpenSSL::Command::verify_cert
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::verify_cert;

use Data::Dumper;
use OpenXPKI::Debug;
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

    ## build the command

    my @command = qw( verify );
    push @command, ('-CAfile', $self->write_temp_file( $self->{TRUSTED} ) );

    push @command, ('-untrusted', $self->write_temp_file( $self->{CHAIN} ) ) if ($self->{CHAIN});

    if ($self->{ATTIME} && $self->{ATTIME} =~ /\A\d+\z/) {
        push @command, "-attime", $self->{ATTIME};
    }

    push @command, ( $self->write_temp_file( $self->{CERTIFICATE} ) );

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
    } elsif ($self->{NOVALIDITY}) {
        # can be replaced by no_check_time with openssl 1.1
        my @res = map { ($_ !~ /(error|OK)/ || $_ =~ /error 10.*expired/)  ? () : $_ } split /\n/, $result;
        ##! 32: 'no validity ' . Dumper \@res
        return ($res[0] && $res[0] eq 'OK') ? -1 : 0;
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

Check if the set of entity, chain and ca certificate build a valid signature
chain (calls openssl verify).

=over

=item CERTIFICATE

=item CHAIN

=item TRUSTED

=item NOVALIDITY

If set to a true value the verification is also true if ertificates in
the chain are expired.

=back

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

Returns 1 if verify is ok, undef if not.
If NOVALIDITY is set, -1 is returned for expired certificates.
