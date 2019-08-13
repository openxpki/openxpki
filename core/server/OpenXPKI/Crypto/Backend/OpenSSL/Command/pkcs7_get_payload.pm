use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_payload;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

use Data::Dumper;

sub get_command
{
    my $self = shift;

    if (not $self->{PKCS7})
    {
        OpenXPKI::Exception->throw (
            message => "pkcs7_get_payload missing pkcs7 data");
    }

    ## build the command
    my @command = qw( cms -verify -noverify -inform PEM  );
    push @command, " -nosigs" if ($self->{NOSIGS});
    push @command, ("-in", $self->write_temp_file( $self->{PKCS7} ));
    push @command, ("-out", $self->get_outfile());
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

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_payload

=head1 Functions

=head2 get_command

Extracts the content (payload) of a PKCS7 non-detached signature container.

The signature on the content itself is checked but the signer certificate
is NOT verified! To extract (and verify) the signer certificate run
pkcs7_verify on the container.

=over

=item * PKCS7 (PKCS7 container with signed content)

=item * NOSIGS set nosigs to ignore skip signature check

=back

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

returns the content on success
