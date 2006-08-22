## OpenXPKI::Server::API::Object.pm 
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 431 $

package OpenXPKI::Server::API::Object;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

use Data::Dumper;

use Regexp::Common;
use Params::Validate qw( validate :types );

use OpenXPKI::Debug 'OpenXPKI::Server::API::Workflow';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

sub BUILD {
    my ($self, $ident, $arg_ref) = @_;
    
    Params::Validate::validation_options(
	# let parameter validation errors throw a proper exception
	on_fail => sub {
	    my $error = shift;
	    
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_API_WORKFLOW_INVALID_PARAMETER",
		params => {
		    ERROR => $error,
		});
	},
	);
}

sub get_csr_info_hash_from_data
{
    ##! 1: "start"
    my $self  = shift;
    my $ident = ident $self;
    validate(
	@_,
	{
	    DATA => {
		type => SCALAR,
		required => 1,
	    }
	});	 
    my $args  = shift;

    my $data  = $args->{DATA};
    my $realm = CTX('session')->get_pki_realm();
    my $token = CTX('pki_realm')->{$realm}->{crypto}->{default};
    my $obj   = OpenXPKI::Crypto::CSR->new (DATA => $data, TOKEN => $token);

    ##! 1: "finished"
    return $obj->get_info_hash();
}

1;
__END__

=head1 Name

OpenXPKI::Server::API::Object

=head1 Description

This is the object interface which should be used by all user interfaces of OpenXPKI.
A user interface MUST NOT access the server directly. The only allowed
access is via this API. Any function which is not available in this API is
not for public use.
The API gets access to the server via the 'server' context object. This
object must be set before instantiating the API.

=head1 Functions

=head2 new

Default constructor created by Class::Std.

=head2 get_csr_info_hash_from_data

return a hash reference which includes all parsed informations from
the CSR. The only accepted parameter is DATA which includes the plain CSR.

