## OpenXPKI::Server::API.pm 
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision$

package OpenXPKI::Server::API;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

use OpenXPKI::Debug 'OpenXPKI::Server::API';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Workflow::Factory;


###########################################################################
# simple retrieval functions

# get current pki realm
sub get_pki_realm {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    return CTX('session')->get_pki_realm();
}

# get current user
sub get_user {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    return CTX('session')->get_user();
}

# get current user
sub get_role {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    return CTX('session')->get_role();
}


# get one or more CA certificates
sub get_ca_certificate {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    my %response;

    ##! 2: "get pki realm configuration"
    my $realms = CTX('pki_realm');
    if (!(defined $realms && (ref $realms eq 'HASH'))) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_GET_CA_CERTIFICATES_PKI_REALM_CONFIGURATION_UNAVAILABLE"
        );
    }

    ##! 2: "get session's realm"
    my $thisrealm = CTX('session')->get_pki_realm();
    ##! 2: "$thisrealm"
    if (! defined $thisrealm) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_GET_CA_CERTIFICATES_PKI_REALM_NOT_SET"
	);
    }

    if (exists $realms->{$thisrealm}->{ca}) {
	# if no ca certificates could be found this key will not exist
	
	foreach my $caid (keys %{$realms->{$thisrealm}->{ca}}) {
	    my $notbefore = 
		$response{$caid} = $realms->{$thisrealm}->{ca}->{id}->{$caid}->{notbefore};
	    my $notafter = 
		$response{$caid} = $realms->{$thisrealm}->{ca}->{id}->{$caid}->{notafter};
	    

	    $response{$caid} = 
	    {
		notbefore => OpenXPKI::DateTime::convert_date(
		    {
			DATE => $realms->{$thisrealm}->{ca}->{id}->{$caid}->{notbefore},
			OUTFORMAT => 'printable',
		    }),
		notafter => OpenXPKI::DateTime::convert_date(
		    {
			DATE => $realms->{$thisrealm}->{ca}->{id}->{$caid}->{notafter},
			OUTFORMAT => 'printable',
		    }),
		cacert => $realms->{$thisrealm}->{ca}->{id}->{$caid}->{crypto}->get_certfile(),

	    }
	}
    }

    return \%response;
}

sub list_ca_ids {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    my %response;

    ##! 2: "get pki realm configuration"
    my $realms = CTX('pki_realm');
    if (!(defined $realms && (ref $realms eq 'HASH'))) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_LIST_CA_IDS_PKI_REALM_CONFIGURATION_UNAVAILABLE"
        );
    }

    ##! 2: "get session's realm"
    my $thisrealm = CTX('session')->get_pki_realm();
    ##! 2: "$thisrealm"
    if (! defined $thisrealm) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_LIST_CA_IDS_PKI_REALM_NOT_SET"
	);
    }

    if (exists $realms->{$thisrealm}->{ca}) {
	
	return sort keys %{$realms->{$thisrealm}->{ca}->{id}};
    }
    
    return;
}


sub list_workflow_instances {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    return [ 123, 456, 789 ];
}

sub list_workflow_titles {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    return [ 'foo', 'bar', 'baz' ];
}


sub create_workflow_instance {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    

}


1;
__END__

=head1 Description

This is the interface which should be used by all user interfaces of OpenXPKI.
A user interface MUST NOT access the server directly. The only allowed
access is via this API. Any function which is not available in this API is
not for public use.
The API gets access to the server via the 'server' context object. This
object must be set before instantiating the API.

=head1 Functions

=head2 new

Default constructor created by Class::Std.

=head2 get_user

Get session user.

=head2 get_role

Get session user's role.

=head2 get_pki_realm

Get PKI realm for this session.

=head2 get_ca_ids

Returns a list of all issuing CA IDs that are available.
Return structure:
  CA_ID => array ref of CA IDs

=head2 get_ca_certificate

Returns CA certificate details.
Expects named parameter 'CA_ID' which can be either a scalar or an 
array ref indicating which CA certificates to fetch.
If named paramter 'OUTFORM' is specified, it must be one of 'PEM' or
'DER'. In this case the returned structure will return the CA certificate
in the specified format.

Returns an array ref containing the CA certificate information in the
order that was requested.

Return structure:
  CACERT => [
    {
        CA_ID => CA ID (as requested)
        NOTBEFORE => certifiate notbefore (ISO8601)
        NOTAFTER => certifiate notafter  (ISO8601)
        CERTIFICATE => certificate data (only if OUTFORM was specified)
    }

  ]

