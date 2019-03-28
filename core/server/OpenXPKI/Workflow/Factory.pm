## OpenXPKI::Workflow::Factory
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project
package OpenXPKI::Workflow::Factory;

use strict;
use warnings;

use Workflow 1.36;
use base qw( Workflow::Factory );
use English;
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow;
use OpenXPKI::Workflow::Context;
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
    ##! 1: 'start'

    $self->__authorize_workflow({
        ACTION => 'create',
        TYPE   => $wf_type,
    });

    if (!$context) {
        $context = OpenXPKI::Workflow::Context->new();
    }

    return $self->SUPER::create_workflow( $wf_type, $context, 'OpenXPKI::Server::Workflow' );
}

sub fetch_workflow {
    my ( $self, $wf_type, $wf_id ) = @_;
    ##! 1: 'start'

    ##! 2: 'calling Workflow::Factory::fetch_workflow()'
    my $wf = $self->SUPER::fetch_workflow($wf_type, $wf_id, undef, 'OpenXPKI::Server::Workflow' )
        or OpenXPKI::Exception->throw(
            message => 'Requested workflow not found',
            params  => {
                WORKFLOW_TYPE => $wf_type,
                WORKFLOW_ID => $wf_id,
            },
        );
    # the following both checks whether the user is allowed to
    # read the workflow at all and deletes context entries from $wf if
    # the configuration mandates it

    ##! 16: 'Fetch Wfl: ' . Dumper $wf;

    $self->__authorize_workflow({
        ACTION   => 'access',
        WORKFLOW => $wf,
        FILTER   => 1,
    });

    $wf->context()->reset_updated();

    return $wf;

}

sub fetch_unfiltered_workflow {
    my ( $self, $wf_type, $wf_id ) = @_;
    ##! 1: 'start'

    my $wf = $self->SUPER::fetch_workflow($wf_type, $wf_id, undef, 'OpenXPKI::Server::Workflow' )
        or OpenXPKI::Exception->throw(
            message => 'Requested workflow not found',
            params  => {
                WORKFLOW_TYPE => $wf_type,
                WORKFLOW_ID => $wf_id,
            },
        );

    $self->__authorize_workflow({
        ACTION   => 'access',
        WORKFLOW => $wf,
        FILTER   => 0,
    });

    CTX('log')->workflow()->info('Unfiltered access to workflow');

    return $wf;

}

sub list_workflow_titles {
    my $self = shift;
    ##! 1: 'start'

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

=head2 get_action_info

Return the UI info for the named action.

Todo: Some of this code is duplicated in the OpenXPKI::Workflow::Config - might
be useful to merge this into a helper. Might be useful in the API.

=cut
sub get_action_info {
    my $self = shift;
    my $action_name = shift;
    my $wf_name = shift; # this can be replaced after creating a lookup map for prefix -> workflow
    ##! 1: 'start'

    my $conn = CTX('config');

    # Check if it is a global or local action
    my ($prefix, $name) = ($action_name =~ m{ \A (\w+?)_(\w+) \z }xs);

    my @path;
    if ($prefix eq 'global') {
        @path = ('workflow','global','action',$name);
    } else {
        @path = ('workflow','def', $wf_name, 'action' , $name);
    }

    my $action = { name => $action_name, label => $action_name };
    foreach my $key (qw(label tooltip description abort resume uihandle)) {
        my $val = $conn->get([ @path, $key]);
        if (defined $val) {
            $action->{$key} = $val;
        }
    }

    my @input = $conn->get_scalar_as_list([ @path, 'input' ]);
    my @fields;
    foreach my $field_name (@input) {
        ##! 64: 'Field info ' . Dumper $field

        my $field = $self->get_field_info( $field_name, $wf_name );

        $field->{type} = 'text' unless ($field->{type});
        $field->{clonable} = ($field->{min} || $field->{max}) || 0;

        push @fields, $field;
    }

    $action->{field} = \@fields if (scalar @fields);

    return $action;
}

sub get_field_info {
    my $self = shift;
    my $field_name = shift;
    my $wf_name = shift;
    ##! 1: 'start'

    my $conn = CTX('config');

    my @field_path;
    # Fields can be defined local or global (only actions inside workflow)
    if ($wf_name) {
        @field_path = ( 'workflow', 'def', $wf_name, 'field', $field_name );
        if (!$conn->exists( \@field_path )) {
            @field_path = ( 'workflow', 'global', 'field', $field_name );
        }
    } else {
        @field_path = ( 'workflow', 'global', 'field', $field_name );
    }

    my $field = $conn->get_hash( \@field_path );

    # Check for option tag and do explicit calls to ensure recursive resolve
    if ($field->{option}) {

        my $mode = $conn->get( [ @field_path, 'option', 'mode' ] ) || 'list';

        my $label = $conn->get( [ @field_path, 'option', 'label' ] );

        my @option;
        if ($mode eq 'keyvalue') {
            @option = $conn->get_list( [ @field_path, 'option', 'item' ] );
        } else {
            my @item;
            if ($mode eq 'keys' || $mode eq 'map') {
                @item = $conn->get_keys( [ @field_path, 'option', 'item' ] );
            } else {
                # option.item holds the items as list, this is mandatory
                @item = $conn->get_list( [ @field_path, 'option', 'item' ] );
            }

            if ($mode eq 'map') {
                # expects that item is a link to a deeper hash structure
                # where the each hash item has a key "label" set
                # will hide items with an empty label
                foreach my $key (@item) {
                    my $label = $conn->get( [ @field_path, 'option', 'item', $key, 'label' ] );
                    next unless ($label);
                    push @option, { value => $key, label => $label };
                }

            } elsif ($label) {
                # if set, we generate the values from option.label + key
                @option = map { { value => $_, label => $label.'_'.uc($_) } } @item;

            } else {
                # the minimum default - use keys as labels
                @option = map { { value => $_, label => $_  } }  @item;
            }
        }
        $field->{option} = \@option;

    }

    return $field;

}

=head2 authorize_workflow

Public wrapper around __authorize_workflow, boolean return (true if
access it granted).

=cut

sub authorize_workflow {
    my $self     = shift;
    my $arg_ref  = shift;
    ##! 1: 'start'

    eval {
        $self->__authorize_workflow( $arg_ref );
    };
    if ($EVAL_ERROR) {
        return 0;
    }
    return 1;

}


sub __authorize_workflow {
    my $self     = shift;
    my $arg_ref  = shift;
    ##! 1: 'start'

    my $conn = CTX('config');

    # Action = create or access
    # Type = Name of the workflow
    # workflow = workflow instance (access)
    # Filter = 0/1 weather to apply filter

    my $action   = $arg_ref->{ACTION};
    ##! 16: 'action: ' . $action

    my $filter   = $arg_ref->{ACTION};
    ##! 16: 'filter: ' . $filter

    my $realm    = CTX('session')->data->pki_realm;
    ##! 16: 'realm: ' . $realm

    my $role     = CTX('session')->data->role;
    $role = 'Anonymous' unless($role);
    ##! 16: 'role: ' . $role

    my $user     = CTX('session')->data->user;
    ##! 16: 'user: ' . $user


    if ($action eq 'create') {
        my $type = $arg_ref->{TYPE};

        $conn->exists([ 'workflow', 'def', $type])
            or OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_UI_WORKFLOW_CREATE_UNKNOWN_TYPE',
                params  => {
                    'REALM'   => $realm,
                    'WF_TYPE' => $type,
                },
            );

        # if creator is set then access is allowed
        $conn->exists([ 'workflow', 'def', $type, 'acl', $role, 'creator' ])
            or OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_UI_WORKFLOW_CREATE_NOT_ALLOWED',
                params  => {
                    'REALM'   => $realm,
                    'ROLE'    => $role,
                    'WF_TYPE' => $type,
                },
            );

        return 1;
    }
    elsif ($action eq 'access') {

        my $workflow = $arg_ref->{WORKFLOW};
        my $filter   = $arg_ref->{FILTER};
        my $type     = $workflow->type();

        my $wf_creator = $workflow->attrib('creator') || '';

        my $is_allowed = $self->check_acl( $type, $wf_creator, $user, $role );

        if (! defined $is_allowed) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_UI_WORKFLOW_ACCESS_NOT_ALLOWED_FOR_ROLE',
                params  => {
                    'REALM'   => $realm,
                    'ROLE'    => $role,
                    'WF_TYPE' => $type,
                },
            );

        } elsif (!$is_allowed) {
            ##! 16: 'workflow creator does not match allowed creator'
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_UI_WORKFLOW_ACCESS_NOT_ALLOWED_FOR_USER',
                params => {
                    'REALM'   => $realm,
                    'ROLE'    => $role,
                    'WF_TYPE' => $type,
                    'ACTIVE_USER' => $user,
                    'WF_CREATOR' => $wf_creator,
                }
            );
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

=head2 check_acl (TYPE, WF_CREATOR, USER, ROLE)

Helper method to evaluate the acl given in the workflow config against
against a concrete instance. Type and creator are mandatory, user and
role is read from the current session if user not set.

Returns 1 if the user can access the workflow. Return undef if no acl
is defined for the current role and 0 if an acl was found but does not
authorize the current user.

=cut

sub check_acl {
    my ($self, $type, $wf_creator, $user, $role) = @_;
    ##! 1: 'start'

    if (!$user) {
        $user = CTX('session')->data->user;
        $role = CTX('session')->data->has_role ? CTX('session')->data->role : 'Anonymous';
    }

    my $allowed_creator_re = CTX('config')->get([ 'workflow', 'def', $type, 'acl', $role, 'creator' ]);
    return unless defined $allowed_creator_re;

    # Creator can be self, any, others or a regex
    my $is_allowed = 0;
    # Access only to own workflows - check session user against creator
    if ($allowed_creator_re eq 'self') {
        $is_allowed = ($wf_creator eq $user);

    # No access to own workflows
    } elsif ($allowed_creator_re eq 'others') {
        $is_allowed = ($wf_creator ne $user);

    # access to any workflow
    } elsif ($allowed_creator_re eq 'any') {
        $is_allowed = 1;

    # Access by Regex - check
    } else {
        $is_allowed = ($wf_creator =~ qr/$allowed_creator_re/);
    }

    return $is_allowed;

}

=head2 update_proc_state($wf, $old_state, $new_state)

Tries to update the C<proc_state> in the database to C<$new_state>.

Returns 1 on success and 0 if e.g. another parallel process already changed the
given C<$old_state>.

=cut
sub update_proc_state {
    my ($self, $wf, $old_state, $new_state) = @_;

    my $wf_config = $self->_get_workflow_config( $wf->type );
    my $persister = $self->get_persister( $wf_config->{persister} );
    return $persister->update_proc_state($wf->id, $old_state, $new_state);
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
