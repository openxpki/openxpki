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

use Regexp::Common;
use Params::Validate qw( validate :types );

use OpenXPKI::Debug 'OpenXPKI::Server::API';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DN;

my %workflow_factory : ATTR;

my $workflow_table = 'WORKFLOW';
my $workflow_history_table = 'WORKFLOW_HISTORY';


# regex definitions for parameter validation
my $re_alpha_string      = qr{ \A [ \w \- \. : \s ]* \z }xms;
my $re_integer_string    = qr{ \A $RE{num}{int} \z }xms;


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

sub get_pki_realm_index
{
    my $self = shift;
    my $pki_realm = CTX('session')->get_pki_realm();

    ## scan for correct pki realm
    my $index = CTX('xml_config')->get_xpath_count (XPATH => "pki_realm");
    for (my $i=0; $i < $index; $i++)
    {
        if (CTX('xml_config')->get_xpath (XPATH   => ["pki_realm", "name"],
                                          COUNTER => [$i, 0])
            eq $pki_realm)
        {
            $index = $i;
        } else {
            if ($index == $i+1)
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_API_GET_PKI_REALM_INDEX_FAILED");
            }
        }
    }

    return $index;
}

sub get_cert_profiles
{
    my $self = shift;
    my $args = shift;

    my $index = $self->get_pki_realm_index();

    ## get all available profiles
    my %profiles = ();
    my $count = CTX('xml_config')->get_xpath_count (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile"],
                    COUNTER => [$index, 0, 0, 0]);
    for (my $i=0; $i <$count; $i++)
    {
        my $id = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "id"],
                    COUNTER => [$index, 0, 0, 0, $i, 0]);
        next if ($id eq "default");
        $profiles{$id} = $i;
    }

    return \%profiles;
}

sub get_cert_subject_profiles
{
    my $self = shift;
    my $args = shift;

    my $index   = $self->get_pki_realm_index();
    my $profile = $args->{PROFILE};

    ## get index of profile
    my $profiles = $self->get_cert_profiles();
       $profile  = $profiles->{$profile};

    ## get all available profiles
    my %profiles = ();
    my $count = CTX('xml_config')->get_xpath_count (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject"],
                    COUNTER => [$index, 0, 0, 0, $profile]);
    for (my $i=0; $i <$count; $i++)
    {
        my $id = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject", "id"],
                    COUNTER => [$index, 0, 0, 0, $profile, $i, 0]);
        my $label = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject", "label"],
                    COUNTER => [$index, 0, 0, 0, $profile, $i, 0]);
        my $desc = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject", "description"],
                    COUNTER => [$index, 0, 0, 0, $profile, $i, 0]);
        $profiles{$id}->{LABEL}       = $label;
        $profiles{$id}->{DESCRIPTION} = $desc;
    }

    return \%profiles;
}

###########################################################################
# lowlevel workflow functions

sub list_workflow_instances {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 1: "list_workflow_instances"

    my $dbi = CTX('dbi_workflow');

    my $instances = $dbi->select(
	TABLE => $workflow_table,
	DYNAMIC => {
	    PKI_REALM  => CTX('session')->get_pki_realm(),
	},
	);

    return $instances;
}


sub list_workflow_titles {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 1: "list_workflow_titles"
    my $factory = $self->__get_workflow_factory();

    # FIXME: we are poking into Workflow::Factory's internal data
    # structures here to get the required information.
    # There really should be accessor methods for this instead in the
    # Workflow class.
    my $result = {};
    if (ref $factory->{_workflow_config} eq 'HASH') {
	foreach my $item (keys %{$factory->{_workflow_config}}) {
	    my $type = $factory->{_workflow_config}->{$item}->{type};
	    my $desc = $factory->{_workflow_config}->{$item}->{description};
	    $result->{$type} = {
		description => $desc,
	    },
	}
    }
    return $result;
}


sub get_workflow_info {
    my $self  = shift;
    my $ident = ident $self;
    validate(
	@_,
	{
	    WORKFLOW => {
		type => SCALAR,
		regex => $re_alpha_string,
	    },
	    ID => {
		type => SCALAR,
		regex => $re_integer_string,
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
		regex => $re_alpha_string,
	    },
	    ID => {
		type => SCALAR,
		regex => $re_integer_string,
	    },
	    ACTIVITY => {
		type => SCALAR,
		regex => $re_alpha_string,
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


sub set_workflow_fields {
    my $self  = shift;
    my $ident = ident $self;
    validate(
	@_,
	{
	    WORKFLOW => {
		type => SCALAR,
		regex => $re_alpha_string,
	    },
	    ID => {
		type => SCALAR,
		regex => $re_integer_string,
	    },
	    PARAMS => {
		type => HASHREF,
		optional => 1,
	    },
	}); 
    my $args  = shift;

    ##! 1: "get_workflow_context"

    my $wf_title    = $args->{WORKFLOW};
    my $wf_id       = $args->{ID};

    my $workflow = $self->__get_workflow_factory()->fetch_workflow(
	$wf_title,
	$wf_id);

    ##! 64: Dumper $workflow

    my $context = $workflow->context();
    ##! 64: Dumper $context

    my $params = $context->param();
    ##! 64: Dumper $params

    return $params;
}


sub create_workflow_instance {
    my $self  = shift;
    my $ident = ident $self;
    validate(
	@_,
	{
	    WORKFLOW => {
		type => SCALAR,
		regex => $re_alpha_string,
	    },
	    PARAMS => {
		type => HASHREF,
		optional => 1,
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

    # pass in specified parameters
    if (exists $args->{PARAMS} &&
	(ref $args->{PARAMS} eq 'HASH')) {
	foreach my $key (keys %{$args->{PARAMS}}) {
	    $workflow->context->param($key => $args->{PARAMS}->{$key});
	}
    }

    my $creator = $self->get_user();
    ##! 2: $creator
    if (! defined $creator) {
	$creator = '';
    }

    $workflow->context->param(creator => $creator);

    # our convention is that every workflow MUST have the following properties:
    # - it must have an activity called 'create'
    # - it must have a state called 'CREATED' that is reached by executing
    #   'create'

    eval
    {
        my $state = $workflow->execute_action('create');

        if ($state ne 'CREATED') {
            my $error = $workflow->context->param('__error');
            if (defined $error) {
                if (ref $error eq '')
                {
                    return
                    {
                     ERROR =>
                     {
                      MESSAGE => $error,
                      TYPE => 'PLAIN',
                     }
                    }
                }
                if (ref $error eq 'ARRAY')
                {
                    return {
                        ERROR => {
                                  STACK => $error,
                                  TYPE => 'STACK',
                        }
                    }
                } 
            }
            return {
                ERROR => {
                MESSAGE => 'I18N_WF_ERROR_ILLEGAL_STATE',
                TYPE => 'PLAIN',
                }
            }
        }
    };
    if ($EVAL_ERROR)
    {
        if ($workflow->context->param('__error'))
        {
            return {
                ERROR => {
                    STACK => $workflow->context->param('__error'),
                    TYPE  => 'STACK',
                }
            }
        }
        if (substr ($EVAL_ERROR, "The following fields require a value:") > -1)
        {
            ## missing field(s) in workflow
            my $fields = $EVAL_ERROR;
               $fields =~ s/^.*://;
            return {
                ERROR => {
                    STACK => [ ["I18N_OPENXPKI_SERVER_API_WORKFLOW_MISSING_REQUIRED_FIELDS",
                                {FIELDS => $fields} ] ],
                    TYPE  => 'STACK',
                }
            }
        }
        $EVAL_ERROR->rethrow();
    }
    
    # commit changes (this is normally not required, as save_workflow()
    # is usually called by execute_action() but in this case we are destroying
    # the workflow instance right after creation.
    #$self->__get_workflow_factory()->save_workflow($workflow);

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

    # lazy initialization is necessary because the Workflow::Factory
    # class calls a Log::Log4perl function in its BEGIN block, causing
    # a warning at runtime if the logging system has not been initialized
    # before
    require Workflow::Factory;

    $workflow_factory{$ident} = Workflow::Factory->instance();


    my $pki_realm = CTX('session')->get_pki_realm();
    my $pki_realm_index;
    
    my $pki_realm_count = CTX('xml_config')->get_xpath_count (XPATH => "pki_realm");

  FINDREALM:
    for (my $ii = 0; $ii < $pki_realm_count; $ii++)
    {
        if (CTX('xml_config')->get_xpath (XPATH   => ["pki_realm", "name"],
					  COUNTER => [$ii,         0])
	    eq $pki_realm) {

            $pki_realm_index = $ii;
	    last FINDREALM;
        }
    }

    if (! defined $pki_realm_index) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_GET_WORKFLOW_FACTORY_INCORRECT_PKI_REALM");
    }

    my %workflow_config = (
	# how we name it in our XML configuration file
	workflows => {
	    # how the parameter is called for Workflow::Factory 
	    factory_param => 'workflow',
	},
	activities => {
	    factory_param => 'action',
	},
	validators => {
	    factory_param => 'validator',
	},
	conditions => {
	    factory_param => 'condition',
	},
	);
    
    foreach my $type (keys %workflow_config) {
	##! 2: "getting workflow '$type' configuration files"

	my $count;
	eval {
	    $count = CTX('xml_config')->get_xpath_count(
		XPATH =>   [ 'pki_realm',      'workflow_config', $type, 'configfile' ],
		COUNTER => [ $pki_realm_index, 0,                 0,      ],
		);
	};
	if (my $exc = OpenXPKI::Exception->caught()) {
	    # ignore missing configuration
	    if (($exc->message() 
		 eq "I18N_OPENXPKI_XML_CONFIG_GET_SUPER_XPATH_NO_INHERITANCE_FOUND")
		&& (($type eq 'validators') || ($type eq 'conditions'))) {
		$count = 0;
	    }
	    else
	    {
		$exc->rethrow();
	    }
	} elsif ($EVAL_ERROR && (ref $EVAL_ERROR)) {
	    $EVAL_ERROR->rethrow();
	}

	if (! defined $count) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_API_GET_WORKFLOW_FACTORY_MISSING_WORKFLOW_CONFIGURATION",
		params => {
		    configtype => $type,
		});
	}


	for (my $ii = 0; $ii < $count; $ii++) {
	    my $entry = CTX('xml_config')->get_xpath (
		XPATH   => [ 'pki_realm', 'workflow_config', $type, 'configfile' ],
		COUNTER => [ $pki_realm_index, 0,            0,     $ii ],
		);
	    ##! 4: "config file: $entry"
	    $workflow_factory{$ident}->add_config_from_file(
		$workflow_config{$type}->{factory_param}  => $entry,
		);
	}
    }

    # persister configuration should not be user-configurable and is
    # static and identical throughout OpenXPKI
    $workflow_factory{$ident}->add_config(
	persister => {
	    name           => 'OpenXPKI',
	    class          => 'OpenXPKI::Server::Workflow::Persister::DBI',
	    workflow_table => $workflow_table,
	    history_table  => $workflow_history_table,
	},
	);

    ##! 64: Dumper $workflow_factory{$ident}

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

=head1 Name

OpenXPKI::Server::API

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

=head2 list_workflow_titles

Returns a hash ref containing all available workflow titles including
a description.

Return structure:
{
  title => description,
  ...
}



