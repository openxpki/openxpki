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

use Data::Dumper;

use Params::Validate qw( validate :types );

use OpenXPKI::Debug 'OpenXPKI::Server::API';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Workflow::Factory;

my %workflow_factory : ATTR;


# regex definitions for parameter validation
my $re_alpha_string      = qr{ \A [ \w \- \. : \s ]* \z }xms;
my $re_integer           = qr{ \A -? \d+ \z }xms;
my $re_positive_integer  = qr{ \A \d+ \z }xms;

my $re_workflow_title    = $re_alpha_string;
my $re_workflow_activity = $re_alpha_string;
my $re_workflow_id       = $re_positive_integer;


sub BUILD {
    my ($self, $ident, $arg_ref) = @_;
    
    Params::Validate::validation_options(
	# let parameter validation errors throw a proper exception
	on_fail => sub {
	    my $error = shift;
	    
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_API_INVALID_PARAMETER",
		params => {
		    ERROR => $error,
		});
	},
	);
}


###########################################################################
# API: simple retrieval functions

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


###########################################################################
# lowlevel workflow functions

sub list_workflow_instances {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 1: "list_workflow_instances"

    return [ 123, 456, 789 ];
}

sub list_workflow_titles {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 1: "list_workflow_titles"

    return [ 'foo', 'bar', 'baz' ];
}


sub get_workflow_info {
    my $self  = shift;
    my $ident = ident $self;
    validate(
	@_,
	{
	    WORKFLOW => {
		type => SCALAR,
		regex => $re_workflow_title,
	    },
	    ID => {
		type => SCALAR,
		regex => $re_workflow_id,
	    },
	});	 
    my $args  = shift;

    ##! 1: "get_workflow_info"

    my $wf_title = $args->{WORKFLOW};
    my $wf_id    = $args->{ID};

    my $workflow = $self->__get_workflow_factory()->fetch_workflow(
	$wf_title,
	$wf_id);

    return $self->__get_workflow_info($workflow);
}

sub execute_workflow_activity {
    my $self  = shift;
    my $ident = ident $self;
    validate(
	@_,
	{
	    WORKFLOW => {
		type => SCALAR,
		regex => $re_workflow_title,
	    },
	    ID => {
		type => SCALAR,
		regex => $re_workflow_id,
	    },
	    ACTIVITY => {
		type => SCALAR,
		regex => $re_workflow_activity,
	    },
	});	 
    my $args  = shift;

    ##! 1: "execute_workflow_activity"

    my $wf_title    = $args->{WORKFLOW};
    my $wf_id       = $args->{ID};
    my $wf_activity = $args->{ACTIVITY};

    my $workflow = $self->__get_workflow_factory()->fetch_workflow(
	$wf_title,
	$wf_id);

    ##! 64: Dumper $workflow
    $workflow->execute_action($wf_activity);
    ##! 64: Dumper $workflow

    return $self->__get_workflow_info($workflow);
}

sub create_workflow_instance {
    my $self  = shift;
    my $ident = ident $self;
    validate(
	@_,
	{
	    WORKFLOW => {
		type => SCALAR,
		regex => $re_workflow_title,
	    },
	});	 
    my $args  = shift;

    ##! 1: "create workflow instance"
    ##! 2: Dumper $args

    my $wf_title = $args->{WORKFLOW};

    # 'data only certificate request'
    my $workflow = $self->__get_workflow_factory()->create_workflow($wf_title);

    if (! defined $workflow) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_ILLEGAL_WORKFLOW_TITLE",
	    params => {
		WORKFLOW => $wf_title,
	    });
    }

    my $creator = $self->get_user();
    ##! 2: $creator
    if (! defined $creator) {
	$creator = '';
    }

    $workflow->context->param(creator => $creator);

    # commit changes (this is normally not required, as save_workflow()
    # is usually called by execute_action() but in this case we are destroying
    # the workflow instance right after creation.
    $self->__get_workflow_factory()->save_workflow($workflow);

    return $self->__get_workflow_info($workflow);
}


###########################################################################
# private functions

sub __get_workflow_factory : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 1: "__get_workflow_factory"

    return $workflow_factory{$ident} if defined $workflow_factory{$ident};

    $workflow_factory{$ident} = Workflow::Factory->instance();

    my $realm_index = 0; # FIXME: compute the correct index!!!

    my $persister_file = CTX('xml_config')->get_xpath (
	XPATH   => [ 'pki_realm', 'workflow_config', 'persisters', 'configfile' ],
	COUNTER => [ $realm_index, 0,          0,            0 ],
	);
    ##! 2: $persister_file

    my $activity_file = CTX('xml_config')->get_xpath (
	XPATH   => [ 'pki_realm', 'workflow_config', 'activities', 'configfile' ],
	COUNTER => [ $realm_index, 0,          0,            0 ],
	);
    ##! 2: $activity_file
	
    my $workflow_file = CTX('xml_config')->get_xpath (
	XPATH   => [ 'pki_realm', 'workflow_config', 'workflows',  'configfile' ],
	COUNTER => [ $realm_index, 0,          0,            0 ],
	);
    ##! 2: $workflow_file

    $workflow_factory{$ident}->add_config_from_file(
	workflow  => $workflow_file,
	action    => $activity_file,
	persister => $persister_file,
	);

    return $workflow_factory{$ident};
}


sub __get_workflow_info : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $workflow  = shift;

    ##! 1: "__get_workflow_info"

    ##! 64: Dumper $workflow

    my $result = {
	WORKFLOW => {
	    ID    => $workflow->id(),
	    STATE => $workflow->state(),
	    CONTEXT => { 
		%{$workflow->context()->param()} 
	    },
	},
    };
    
    foreach my $activity ($workflow->get_current_actions()) {
	##! 2: $activity

	# FIXME - bug in Workflow::Action (v0.17)?: if no fields are defined the
	# method tries to return an arrayref on an undef'd value
	my @fields;
	eval {
	    @fields = $workflow->get_action_fields($activity);
	};
	
	foreach my $field (@fields) {
	    ##! 4: $field->name()
	    $result->{ACTIVITY}->{$activity}->{FIELD}->{$field->name()} =
	    {
		DESCRIPTION => $field->description(),
		REQUIRED    => $field->is_required(),
	    };
	}
    }


    return $result;
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

