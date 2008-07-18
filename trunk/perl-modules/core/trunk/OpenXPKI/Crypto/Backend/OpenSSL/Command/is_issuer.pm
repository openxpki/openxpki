## OpenXPKI::Crypto::Backend::OpenSSL::Command::is_issuer
## Written 2008 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2008 by The OpenXPKI Project
package OpenXPKI::Crypto::Backend::OpenSSL::Command::is_issuer;
use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

use strict;
use warnings;

use OpenXPKI::Debug;
use OpenXPKI::FileUtils;

use Data::Dumper;

sub get_command
{
    my $self  = shift;

    my $fu = OpenXPKI::FileUtils->new();
    my $cafile = $fu->get_safe_tmpfile({
        TMP => $self->{TMP},
    });
    ##! 64: 'cafile: ' . $cafile
    my $certfile = $fu->get_safe_tmpfile({
        TMP => $self->{TMP},
    });
    ##! 64: 'certfile: ' . $certfile

    $self->write_file(
        FILENAME => $cafile,
        CONTENT  => $self->{'POTENTIAL_ISSUER'},
        FORCE    => 1,
    );

    $self->write_file(
        FILENAME => $certfile,
        CONTENT  => $self->{'CERT'},
        FORCE    => 1,
    );

    ## build the command

    # the empty -CApath parameter is needed because otherwise OpenSSL
    # will (silently the man page ignores this issue) use the system
    # cert directory as well ...
    my $command  = "verify -CAfile $cafile -CApath -verbose $certfile";

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
    my $self   = shift;
    my $result = shift;
    ##! 16: 'result: ' . $result
    #return $result;
    if ($result =~ m{ error }xms) {
        return 0;
    }
    elsif ($result =~ m{ OK \n \z }xms) {
        return 1;
    }
    else {
        return 0;
    }
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::is_issuer

=head1 Functions

=head2 get_command

=over

=item * CERT

=item * POTENTIAL_ISSUER

=back

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

Returns true if POTENTIAL_ISSUER is the signer of CERT, false otherwise.
