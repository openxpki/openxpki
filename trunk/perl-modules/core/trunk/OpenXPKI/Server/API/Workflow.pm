## OpenXPKI::Server::API::Workflow.pm 
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 431 $

package OpenXPKI::Server::API::Workflow;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;
use Workflow::Factory;
use Data::Dumper;

use OpenXPKI::Debug 'OpenXPKI::Server::API::Workflow';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::Observer::AddExecuteHistory;

my $workflow_table = 'WORKFLOW';
my $context_table  = 'WORKFLOW_CONTEXT';
my $workflow_history_table = 'WORKFLOW_HISTORY';

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}

###########################################################################
# lowlevel workflow functions

sub list_workflow_instances {
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
    ##! 1: "list_workflow_titles"
    my $factory = __get_workflow_factory();

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
    my $args  = shift;

    ##! 1: "get_workflow_info"

    my $wf_title = $args->{WORKFLOW};
    my $wf_id    = $args->{ID};

    my $workflow = __get_workflow_factory()->fetch_workflow(
	$wf_title,
	$wf_id);

    return __get_workflow_info($workflow);
}

sub execute_workflow_activity {
    my $self  = shift;
    my $args  = shift;

    ##! 1: "execute_workflow_activity"

    my $wf_title    = $args->{WORKFLOW};
    my $wf_id       = $args->{ID};
    my $wf_activity = $args->{ACTIVITY};
    my $wf_params   = $args->{PARAMS};

    ##! 2: "load workflow"
    my $workflow = __get_workflow_factory()->fetch_workflow(
	$wf_title,
	$wf_id);
    $workflow->delete_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');
    $workflow->add_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');

    ##! 2: "check parameters"
    my %fields = ();
    foreach my $field ($workflow->get_action_fields($wf_activity))
    {
        $fields{$field->name()} = $field->description();
    }
    foreach my $key (keys %{$wf_params})
    {
        if (not exists $fields{$key})
        {
	    OpenXPKI::Exception->throw (
	        message => "I18N_OPENXPKI_SERVER_API_EXECUTE_WORKFLOW_ACTIVITY_ILLEGAL_PARAM",
	        params => {
		    WORKFLOW => $wf_title,
                    ID       => $wf_id,
                    ACTIVITY => $wf_activity,
                    PARAM    => $key,
                    VALUE    => $wf_params->{$key}
	        });
        }
    }

    ##! 2: "set parameters"
    my $context = $workflow->context();
    $context->param ($wf_params);

    ##! 64: Dumper $workflow
    eval {
        $workflow->execute_action($wf_activity);
    };
    if ($EVAL_ERROR) {
        my $eval = $EVAL_ERROR;

        ## normal OpenXPKI exception
        $eval->rethrow() if (ref $eval eq "OpenXPKI::Exception");

        ## workflow exception
        my $error = $workflow->context->param('__error');
        if (defined $error)
        {
            if (ref $error eq '')
            {
                OpenXPKI::Exception->throw (
                    message => $error);
            }
            if (ref $error eq 'ARRAY')
            {
                my @list = ();
                foreach my $item (@{$error})
                {
                    eval {
                        OpenXPKI::Exception->throw (
                            message => $item->[0],
                            params  => $item->[1]);
                    };
                    push @list, $EVAL_ERROR;
                }
                OpenXPKI::Exception->throw (
                    message  => "I18N_OPENXPKI_SERVER_API_EXECUTE_WORKFLOW_ACTIVITY_FAILED",
                    children => [ @list ]);
            } 
        }

        ## unknown exception
        OpenXPKI::Exception->throw (message => scalar $eval);
    };
    ##! 64: Dumper $workflow

    return __get_workflow_info($workflow);
}

sub create_workflow_instance {
    my $self  = shift;
    my $args  = shift;

    ##! 1: "create workflow instance"
    ##! 2: Dumper $args

    my $wf_title = $args->{WORKFLOW};

    # 'data only certificate request'
    my $workflow = __get_workflow_factory()->create_workflow($wf_title);

    if (! defined $workflow) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_ILLEGAL_WORKFLOW_TITLE",
	    params => {
		WORKFLOW => $wf_title,
	    });
    }
    $workflow->delete_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');
    $workflow->add_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');

    my $creator = CTX('session')->get_user();
    ##! 2: $creator
    if (! defined $creator) {
	$creator = '';
    }

    $workflow->context->param(creator => $creator);

    # our convention is that every workflow MUST have the following properties:
    # - it must have an activity called 'create'
    # - it must have a state called 'CREATED' that is reached by executing
    #   'create'

    my $state = undef;
    eval
    {
        ##! 4: "determine the first action"
        my @list = $workflow->get_current_actions();
        if (not scalar @list)
        {
	    OpenXPKI::Exception->throw (
	        message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_NO_FIRST_ACTIVITY",
	        params => {
		    WORKFLOW => $wf_title,
	        });
        }
        ##! 4: "pass in specified parameters if available"
        if (exists $args->{PARAMS} &&
            (ref $args->{PARAMS} eq 'HASH'))
        {
            ##! 8: "load allowed parameters"
            my %fields = ();
            foreach my $field ($workflow->get_action_fields($list[0]))
            {
                $fields{$field->name()} = $field->description();
            }
            ##! 8: "store the allowed parameters"
	    foreach my $key (keys %{$args->{PARAMS}})
            {
                next if (not exists $fields{$key} and $args->{FILTER_PARAMS});
                if (not exists $fields{$key})
                {
                    OpenXPKI::Exception->throw (
                        message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_ILLEGAL_PARAM",
                        params => {
                                   WORKFLOW => $wf_title,
                                   ACTIVITY => $list[0],
                                   PARAM    => $key,
                                   VALUE    => $args->{PARAMS}->{$key}
                                  });
                }
	        $workflow->context->param($key => $args->{PARAMS}->{$key});
            }
        }
        $state = $workflow->execute_action($list[0]);
    };

    if ($EVAL_ERROR or $state eq 'INITIAL') {
        my $eval = $EVAL_ERROR;
        my $error = $workflow->context->param('__error');
        if (defined $error) {
            if (ref $error eq '')
            {
                OpenXPKI::Exception->throw (
                    message => $error);
            }
            if (ref $error eq 'ARRAY')
            {
                my @list = ();
                foreach my $item (@{$error})
                {
                    eval {
                        OpenXPKI::Exception->throw (
                            message => $item->[0],
                            params  => $item->[1]);
                    };
                    push @list, $EVAL_ERROR;
                }
                OpenXPKI::Exception->throw (
                    message  => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_CREATE_FAILED",
                    children => [ @list ]);
            } 
        }
        if ($eval)
        {
            if (index ($eval, "The following fields require a value:") > -1)
            {
                ## missing field(s) in workflow
                $eval =~ s/^.*://;
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_API_WORKFLOW_MISSING_REQUIRED_FIELDS",
                    params  => {FIELDS => $eval});
            }
            $eval->rethrow();
        }
        OpenXPKI::Exception->throw (
                message => 'I18N_WF_ERROR_ILLEGAL_STATE');
    };
    
    return __get_workflow_info($workflow);
}

sub get_workflow_activities {
    my $self  = shift;
    my $args  = shift;

    my $wf_title = $args->{WORKFLOW};
    my $wf_id    = $args->{ID};

    my $workflow = __get_workflow_factory()->fetch_workflow(
	$wf_title,
	$wf_id);
    my @list = $workflow->get_current_actions();

    ##! 1: "finished"
    return \@list;
}

sub search_workflow_instances {
    my $self     = shift;
    my $arg_ref  = shift;

    my $dbi = CTX('dbi_workflow');
    my $realm = CTX('session')->get_pki_realm();

    if (scalar @{$arg_ref->{CONTEXT}} == 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_SEARCH_WORKFLOW_INSTANCES_NEED_AT_LEAST_ONE_CONTEXT_ENTRY',
        );
    }
    my $dynamic;
    my @tables;
    my @joins;
    ## create complex select structures, similar to the following:
    # $dbi->select(
    #    TABLE    => [ { WORKFLOW_CONTEXT => WORKFLOW_CONTEXT_0},
    #                  { WORKFLOW_CONTEXT => WORKFLOW_CONTEXT_1},
    #                  WORKFLOW
    #                ],
    #    COLUMNS   => ...
    #    JOIN      => [ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL' ],
    #    DYNAMIC   => {
    #                   WORKFLOW_CONTEXT_0.WORKFLOW_CONTEXT_KEY = $key1,
    #                   WORKFLOW_CONTEXT_0.WORKFLOW_CONTEXT_VALUE = $value1,
    #                   WORKFLOW_CONTEXT_1.WORKFLOW_CONTEXT_KEY = $key2,
    #                   WORKFLOW_CONTEXT_1.WORKFLOW_CONTEXT_VALUE = $value2,
    #                   WORKFLOW.PKI_REALM = $realm,
    #                 },
    # );
    my $i = 0;
    foreach my $context_entry (@{$arg_ref->{CONTEXT}}) {
        my $table_alias = $context_table . '_' . $i;
        my $key   = $context_entry->{KEY};
        my $value = $context_entry->{VALUE};
        $dynamic->{$table_alias . '.WORKFLOW_CONTEXT_KEY'}   = $key;
        $dynamic->{$table_alias . '.WORKFLOW_CONTEXT_VALUE'} = $value;
        push @tables, [ $context_table => $table_alias ];
        push @joins, 'WORKFLOW_SERIAL';
        $i++;
    }
    push @tables, $workflow_table;
    push @joins, 'WORKFLOW_SERIAL';
    $dynamic->{$workflow_table . '.PKI_REALM'} = $realm;

    if (defined $arg_ref->{TYPE}) {
        $dynamic->{$workflow_table . '.WORKFLOW_TYPE'} = $arg_ref->{TYPE};
    }

    ##! 16: 'dynamic: ' . Dumper $dynamic
    ##! 16: 'tables: ' . Dumper(\@tables)
    my $result = $dbi->select(
	TABLE   => \@tables,
        COLUMNS => [
                         $workflow_table . '.WORKFLOW_SERIAL',
                         $workflow_table . '.WORKFLOW_TYPE',
                         $workflow_table . '.WORKFLOW_STATE',
                         $workflow_table . '.WORKFLOW_LAST_UPDATE',
                   ],
        JOIN    => [
                         \@joins,
                   ],
	DYNAMIC => $dynamic,
    );
    ##! 16: 'result: ' . Dumper $result
    return $result;
}
 
###########################################################################
# private functions

sub __get_workflow_factory {
    my $args  = shift;

    ##! 1: "__get_workflow_factory"

    my $workflow_factory = Workflow::Factory->instance();


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
	    $workflow_factory->add_config_from_file(
		$workflow_config{$type}->{factory_param}  => $entry,
		);
	}
    }

    # persister configuration should not be user-configurable and is
    # static and identical throughout OpenXPKI
    $workflow_factory->add_config(
	persister => {
	    name           => 'OpenXPKI',
	    class          => 'OpenXPKI::Server::Workflow::Persister::DBI',
	    workflow_table => $workflow_table,
	    history_table  => $workflow_history_table,
	},
	);

    ##! 64: Dumper $workflow_factory

    return $workflow_factory;
}


sub __get_workflow_info {
    my $workflow  = shift;

    ##! 1: "__get_workflow_info"

    ##! 64: Dumper $workflow

    my $result = {
	WORKFLOW => {
	    ID          => $workflow->id(),
	    STATE       => $workflow->state(),
	    TYPE        => $workflow->type(),
	    DESCRIPTION => $workflow->description(),
	    LAST_UPDATE => $workflow->last_update(),
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

OpenXPKI::Server::API::Workflow

=head1 Description

This is the workflow interface which should be used by all user interfaces of OpenXPKI.
A user interface MUST NOT access the server directly. The only allowed
access is via this API. Any function which is not available in this API is
not for public use.
The API gets access to the server via the 'server' context object. This
object must be set before instantiating the API.

=head1 Functions

=head2 new

Default constructor created by Class::Std.

=head2 list_workflow_titles

Returns a hash ref containing all available workflow titles including
a description.

Return structure:
{
  title => description,
  ...
}

=head2 search_workflow_instances

This function accesses the database directly in order to find
Workflow instances matching the specified search criteria.

Returns an array reference of the database query result.

Named parameters:

=over

=item * CONTEXT

The named parameter CONTEXT must be a hash reference.
Apply search filter to search using the KEY/VALUE pair passed in
CONTEXT and match all Workflow instances whose context contain all
of the specified tuples.
It is possible to use SQL wildcards such as % in the VALUE field.

=back

Examples:

  my @workflow_ids = $api->search_workflow_instances(
      {
	  CONTEXT =>
	      {
		  KEY   => 'SCEP_TID',
		  VALUE => 'ECB001D912E2A357E6E813D87A72E641',
	      },
      }


