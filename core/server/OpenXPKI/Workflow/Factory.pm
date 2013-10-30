## OpenXPKI::Workflow::Factory
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project
package OpenXPKI::Workflow::Factory;

use strict;
use warnings;

use Workflow 1.36;
use base qw( Workflow::Factory );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow;
use Workflow::Exception qw( configuration_error workflow_error );
use Data::Dumper; 


sub new {
    my $class = ref $_[0] || $_[0];
    return bless( {} => $class );
}

sub instance {    
    # To stay compatible to the Workflow Module, accept instance on exisiting instances
    my $self = shift;
    return $self if (ref $self);
     
    # use "new", not instance to create a new one
    OpenXPKI::Exception->throw (message => "I18N_OPENXPKI_WORKFLOW_FACTORY_INSTANCE_METHOD_NOT_SUPPORTED");    
}

sub create_workflow{
    
    my ( $self, $wf_type, $context ) = @_;    
    
    $self->__authorize_workflow({
        ACTION => 'create',
        TYPE   => $wf_type,
    });
    
    return $self->SUPER::create_workflow( $wf_type, $context, 'OpenXPKI::Server::Workflow' );     
}

sub fetch_workflow {
    my ( $self, $wf_type, $wf_id ) = @_;
    
    
    my $wf = $self->SUPER::fetch_workflow($wf_type, $wf_id, undef, 'OpenXPKI::Server::Workflow' );
    # the following both checks whether the user is allowed to
    # read the workflow at all and deletes context entries from $wf if
    # the configuration mandates it
    
	##! 16: 'Fetch Wfl: ' . Dumper $wf;
	    
    $self->__authorize_workflow({
        ACTION   => 'access',
        WORKFLOW => $wf,
        FILTER   => 1,
    });
    
    return $wf; 
     
}

sub fetch_unfiltered_workflow {    
    my ( $self, $wf_type, $wf_id ) = @_;
    my $wf = $self->SUPER::fetch_workflow($wf_type, $wf_id, undef, 'OpenXPKI::Server::Workflow' );
    
    $self->__authorize_workflow({
        ACTION   => 'access',
        WORKFLOW => $wf,
        FILTER   => 0,
    });

    CTX('log')->log(
        MESSAGE  => 'Unfiltered access to workflow ' . $wf->id . ' by ' . CTX('session')->get_user() . ' with role ' . CTX('session')->get_role(),
        PRIORITY => 'info',
        FACILITY => 'audit',
    );

	return $wf;

}

sub list_workflow_titles {
    
    my $self = shift;

    my $result = {};
    # Nothing initialised
    if (ref $self->{_workflow_config} ne 'HASH') {
        return $result;
    }
        
    foreach my $item (keys %{$self->{_workflow_config}}) {
        my $type = $self->{_workflow_config}->{$item}->{type};
        my $desc = $self->{_workflow_config}->{$item}->{description};
        $result->{$type} = { label => $type, description => $desc || $type }
    }    
    return $result;
}

sub get_activity_info {
    
    my $self = shift;
    my $args = shift;
        
    my $activity = $args->{ACTIVITY};
    
    ##! 2: $activity
    
    # We extract the values from the action definition for ui rendering
    my $info = $self->{_action_config}->{default}->{$activity};

    my $result = {
        LABEL => $info->{description} || $activity        
    };
    $result->{UIHANDLE} = $info->{uihandle} if ($info->{uihandle});
    
    my @fields;
    foreach my $field (@{$info->{field}}) {        
        ##! 64: 'Field info ' . Dumper $field
        
        push @fields, {
            name => $field->{name},
            label => $field->{label} || $field->{name},
            type => $field->{type} || 'text',
            required => ($field->{is_required} && $field->{is_required} eq 'yes') || 0,                        
        }        
    }

    return $result;
}

sub __authorize_workflow {
        
    my $self     = shift;
    my $arg_ref  = shift;
    
    my $config = CTX('config');
    
    # Action = create or access
    # Type = Name of the workflow
    # workflow = workflow instance (access)
    # Filter = 0/1 weather to apply filter
    
    my $action   = $arg_ref->{ACTION};
    ##! 16: 'action: ' . $action
    
    my $filter   = $arg_ref->{ACTION};
    ##! 16: 'filter: ' . $filter
       
    my $realm    = CTX('session')->get_pki_realm();
    ##! 16: 'realm: ' . $realm
    
    my $role     = CTX('session')->get_role();    
    $role = 'Anonymous' unless($role);       
    ##! 16: 'role: ' . $role
    
    my $user     = CTX('session')->get_user();
    ##! 16: 'user: ' . $user

    
    if ($action eq 'create') {
        my $type = $arg_ref->{TYPE};
       
        my %allowed_workflows = map { $_ => 1 } ($config->get_list("auth.wfacl.$role.create"));
         
        ##! 16: 'allowed workflows ' . Dumper \%allowed_workflows               
        if (! exists $allowed_workflows{$type} ) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_CREATE_PERMISSION_DENIED',
                params  => {
                    'REALM'   => $realm,
                    'ROLE'    => $role,
                    'WF_TYPE' => $type,
                },
            );
        }
        return 1;
    } 
    elsif ($action eq 'access') {
        my $workflow = $arg_ref->{WORKFLOW};
        my $filter   = $arg_ref->{FILTER};
        my $type     = $workflow->type();
        
        my $allowed_creator_re = $config->get("auth.wfacl.$role.access.$type.creator"); 
        
        if (! defined $allowed_creator_re) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_READ_PERMISSION_DENIED_NO_ACCESS_TO_TYPE',
                params  => {
                    'REALM'   => $realm,
                    'ROLE'    => $role,
                    'WF_TYPE' => $type,
                },
            );
        }
        
        if ($allowed_creator_re eq 'self') {
            # this is a meta name, replace by current user name
            $allowed_creator_re = $user;
        }
        if ($allowed_creator_re) {
            ##! 16: 'allowed_creator_re: ' . $allowed_creator_re
            # check it against the workflow creator
            my $wf_creator = $workflow->context()->param('creator') || '';
            #my $wf_creator = $workflow->attrib('creator') || '';
            
            ##! 16: 'wf_creator: ' . $wf_creator
            if ($wf_creator !~ qr/$allowed_creator_re/ &&
                $wf_creator ne $allowed_creator_re) {
                ##! 16: 'workflow creator does not match allowed creator'
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_READ_PERMISSION_DENIED_WORKFLOW_CREATOR_NOT_ACCEPTABLE',
                );
            }
        }
        
         
        my $context_filter = $config->get_hash("auth.wfacl.$role.access.$type.context");                
        if ($filter &&  $context_filter) {
            # context filtering is defined for this type, so
            # iterate over the context parameters and check them against
            # the show/hide configuration values
            my $show = $context_filter->{show};
            if (! defined $show) {
                $show = ''; # will not filter anything! 
            }
            ##! 16: 'show: ' . $show
            
            my $hide = $context_filter->{hide};
            if (! defined $hide) {
                $hide = ''; # liberal default: do not hide anything
            }
            my %original_params = %{ $workflow->context()->param() };
            # clear workflow context so that we can add the ones
            # that the user is allowed to see to it again ...
            $workflow->context()->clear_params();

            ##! 64: 'original_params before filtering: ' . Dumper \%original_params
            foreach my $key (keys %original_params) {
                ##! 64: 'key: ' . $key
                my $add = 1;
                if ($show) {
                    ##! 16: 'show present, checking against it'
                    if ($key !~ qr/$show/) {
                        ##! 16: 'key ' . $key . ' did not match ' . $show
                        $add = 0;
                    }
                }
                if ($hide) {
                    ##! 16: 'hide present, checking against it'
                    if ($key =~ qr/$hide/) {
                        ##! 16: 'key ' . $key . ' matches ' . $hide
                        $add = 0;
                    }
                }
                if ($add) {
                    ##! 16: 'adding key: ' . $key
                    $workflow->context()->param(
                        $key => $original_params{$key},
                    );
                }
            }
            ##! 64: 'workflow_context after filtering: ' . Dumper $workflow->context->param()
        }
        return 1;
    }
    else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_UNKNOWN_ACTION',
            params  => {
                'ACTION' => $action,
            },
        );
    }
    # this code should be unreachable. In case it is not, throw an exception
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_INTERNAL_ERROR',
    );
}


1;
__END__

=head1 Name

OpenXPKI::Workflow::Factory - OpenXPKI specific workflow factory

=head1 Description

This is the OpenXPKI specific subclass of Workflow::Factory.
We need an OpenXPKI specific subclass because Workflow currently
enforces that a Factory is a singleton. In OpenXPKI, we want to have
several factory objects (one for each version and each PKI realm).
The most important difference between Workflow::Factory and
OpenXPKI::Workflow::Factory is in the instance() class method, which
creates only one global instance in the original and a new one for
each call in the OpenXPKI version.

In addition, the fetch_workflow() method has been modified to do ACL
checks before returning the workflow to the caller. Typically, it also
'censors' the workflow context by removing certain workflow context
entries. Unfiltered access is possible via fetch_unfiltered_workflow()
- please note that this is sort of an ACL circumvention and should only
be used if really necessary (and should only be used to create a temporary
object that is used to retrieve the relevant entries).


All methods return an object of class OpenXPKI::Server::Workflow, which is derived 
from Workflow base class and implements the pause/resume-features. see there for details.
