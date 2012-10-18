## OpenXPKI::Server::API::Secret.pm 
##
## Written 2006 by Michael Bell for the OpenXPKI project
## Copyright (C) 2006 by The OpenXPKI Project

package OpenXPKI::Server::API::Secret;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::Secret;

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}

sub get_secrets
{
    ##! 1: "start, forward and finish"
    return { CTX('crypto_layer')->get_secret_groups() };
}

sub is_secret_complete
{
    ##! 1: "start, forward and finish"
    my $self = shift;
    my $args = shift;
    return CTX('crypto_layer')->is_secret_group_complete($args->{SECRET});
}

sub set_secret_part
{
    ##! 1: "start, forward and finish"
    my $self = shift;
    my $args = shift;

    my $result = 
	CTX('crypto_layer')->set_secret_group_part(
	    {
		GROUP => $args->{SECRET},
		PART  => $args->{PART},
		VALUE => $args->{VALUE}
	    });

    if ($result) {
	CTX('log')->log(
	    MESSAGE  => "Secret part $args->{PART} set for group $args->{SECRET}",
	    PRIORITY => 'info',
	    FACILITY => 'audit',
	    );
    } else {
	CTX('log')->log(
	    MESSAGE  => "Incorrect secret part $args->{PART} entered for group $args->{SECRET}",
	    PRIORITY => 'warn',
	    FACILITY => 'audit',
	    );
    }
    
    return $result;
}

sub clear_secret
{
    ##! 1: "start, forward and finish"
    my $self = shift;
    my $args = shift;

    CTX('log')->log(
	MESSAGE  => "Clearing secret for group $args->{SECRET}",
	PRIORITY => 'info',
	FACILITY => 'audit',
	);

    return CTX('crypto_layer')->clear_secret_group($args->{SECRET});
}

1;
__END__

=head1 Name

OpenXPKI::Server::API::Secret

=head1 Description

This API implements all relevant functions which are necessary
to use the private keys on this machine. Mainly it give informations
about the different authentication groups for secret and it supplies
an interface to set passphrase or parts of passphrases.

=head1 Functions

=head2 get_group_secrets

=head2 is_group_secret_complete

=head2 set_group_secret_part

=head2 clear_secret

=head1 See also

OpenXPKI::Server::API, OpenXPKI::Crypto::Secret and OpenXPKI::Crypto::VolatileVault
