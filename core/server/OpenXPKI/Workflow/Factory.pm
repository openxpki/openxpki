package OpenXPKI::Workflow::Factory;

use strict;
use warnings;

use Workflow 1.36;
use base qw( Workflow::Factory );
use English;
use Scalar::Util qw( blessed );
use Type::Params qw( signature_for );

use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow;
use OpenXPKI::Workflow::Context;
use OpenXPKI::Workflow::Field;
use Workflow::Exception qw( configuration_error workflow_error );

use experimental 'signatures'; # should be done after imports to safely disable warnings in Perl < 5.36

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

sub _create_wf {
    my ( $self, $wf_type, $context, $create_as ) = @_;

    OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_UI_WORKFLOW_CREATE_NOT_ALLOWED',
        params =>  { type => $wf_type }
    ) unless($self->can_create_workflow($wf_type, $create_as));

    if (!$context) {
        $context = OpenXPKI::Workflow::Context->new();
    }

    return $self->SUPER::create_workflow( $wf_type, $context, 'OpenXPKI::Server::Workflow' );
}

sub create_workflow {
    my ( $self, $wf_type, $context ) = @_;
    ##! 1: 'start'
    return $self->_create_wf($wf_type, $context)
}

sub create_workflow_as_system {
    my ( $self, $wf_type, $context,  ) = @_;
    ##! 1: 'start'
    return $self->_create_wf($wf_type, $context, 'System')
}

sub fetch_workflow {

    my ( $self, $wf_type, $wf_id ) = @_;
    ##! 1: 'start'

    ##! 2: 'calling Workflow::Factory::fetch_workflow()'
    my $wf = $self->SUPER::fetch_workflow($wf_type, $wf_id, undef, 'OpenXPKI::Server::Workflow' )
        or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_UI_WORKFLOW_HANDLER_ID_NOT_FOUND',
            params  => {
                WORKFLOW_TYPE => $wf_type,
                WORKFLOW_ID => $wf_id,
            },
        );

    $self->can_access_workflow({
        type =>    $wf->type,
        creator => $wf->attrib('creator'),
        tenant =>  $wf->attrib('tenant')
    })
    or OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_UI_WORKFLOW_ACCESS_NOT_ALLOWED_FOR_USER',
        params  => { type => $wf->type, id => $wf->id },
    );

    $wf->context()->reset_updated();

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

=cut

# TODO: Some of this code is duplicated in the OpenXPKI::Workflow::Config - might be useful to merge this into a helper. Might be useful in the API.

sub get_action_info {
    my $self = shift;
    my $action_name = shift;
    my $wf_name = shift; # this can be replaced after creating a lookup map for prefix -> workflow
    ##! 1: 'start'

    my $conn = CTX('config');

    # Check if it is a global or local action
    my ($prefix, $name) = ($action_name =~ m{ \A (\w+?)_(\w+) \z }xs);

    my @path;
    if (($prefix//'') eq 'global') {
        @path = ('workflow','global','action',$name);
    } else {
        @path = ('workflow','def', $wf_name, 'action' , $name);
    }

    my $action = { name => $action_name, label => $action_name };
    foreach my $key (qw(label tooltip description template abort resume uihandle button)) {
        my $val = $conn->get([ @path, $key]);
        if (defined $val) {
            $action->{$key} = $val;
        }
    }

    my @input = $conn->get_scalar_as_list([ @path, 'input' ]);
    my @fields;
    foreach my $field_name (@input) {
        my $field = $self->get_field_info( $field_name, $wf_name );
        ##! 64: 'Field info: ' . Dumper $field
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

    my $config = CTX('config');

    my @field_path;
    # Fields can be defined local or global (only actions inside workflow)
    if ($wf_name) {
        @field_path = ( 'workflow', 'def', $wf_name, 'field', $field_name );
        if (!$config->exists( \@field_path )) {
            @field_path = ( 'workflow', 'global', 'field', $field_name );
        }
    } else {
        @field_path = ( 'workflow', 'global', 'field', $field_name );
    }

    my $field = $config->get_hash( \@field_path );

    # set field's context key to the field name
    $field->{name} //= $field_name;

    OpenXPKI::Workflow::Field->process(
        field => $field,
        config => $config,
        path => \@field_path,
    );

    return $field;
}

# Returns a HashRef with configuration details (actions, states) of the given
# workflow type and state.
signature_for get_action_and_state_info => (
    method => 1,
    positional => [
        'Str',
        'Str',
        'ArrayRef',
        'Optional[ HashRef | Undef ]', { default => {} },
    ],
);
sub get_action_and_state_info ($self, $type, $state, $actions, $context) {
    ##! 4: 'start'

    my $head = CTX('config')->get_hash([ 'workflow', 'def', $type, 'head' ]);
    my $wf_prefix = $head->{prefix};

    #
    # add activities (= actions)
    #
    my $action_info = {};

    OpenXPKI::Connector::WorkflowContext::set_context($context) if $context;
    for my $action (@{ $actions }) {
        $action_info->{$action} = $self->get_action_info($action, $type);
    }
    OpenXPKI::Connector::WorkflowContext::set_context() if $context;

    #
    # add state UI info
    #
    my $state_info = CTX('config')->get_hash([ 'workflow', 'def', $type, 'state', $state ]);

    # replace hash key "output" with detailed field informations
    if ($state_info->{output}) {
        my @output_fields = ref $state_info->{output} eq 'ARRAY'
            ? @{ $state_info->{output} }
            : CTX('config')->get_list([ 'workflow', 'def', $type, 'state', $state, 'output' ]);

        # query detailed field informations
        $state_info->{output} = [ map { $self->get_field_info($_, $type) } @output_fields ];
    }

    # add button info
    my $button = $state_info->{button};
    $state_info->{button} = {};

    # possible actions (options / activity names) in the right order
    delete $state_info->{action};
    my @options = CTX('config')->get_scalar_as_list([ 'workflow', 'def', $type, 'state', $state, 'action' ]);

    # check defined actions and only list the possible ones
    # (non global actions are prefixed)
    ##! 64: 'Available actions: ' . join(', ', keys %$action_info)
    $state_info->{option} = [];
    if ($state_info->{autoselect} && $state_info->{autoselect} !~ m{\Aglobal_}) {
        $state_info->{autoselect} = $wf_prefix.'_'.$state_info->{autoselect};
    }
    for my $option (@options) {
        $option =~ m{ \A (\W?)((global_)?([^\s>]+))}xs;
        $option = $2;

        my $action_prefix = $1;
        my $full = $2;
        my $global = $3;
        my $option_base = $4;

        # evaluate action prefix
        my $auto = 0;
        if ($action_prefix eq '~') {
            $auto = 1;
        }
        elsif (not defined $action_prefix or $action_prefix eq '') {
            # ok
        }
        else {
            OpenXPKI::Exception->throw(
                message => 'Action contains unknown prefix. Currently supported: "~" (autoselect action)',
                params  => {
                    action => $option,
                    prefix => $action_prefix,
                },
            );
        }

        my $action = sprintf("%s_%s", $global ? "global" : $wf_prefix, $option_base);
        ##! 16: 'Action: ' . $action
        next unless($action_info->{$action});

        push @{$state_info->{option}}, $action;
        if ($auto && !$state_info->{autoselect}) {
            $state_info->{autoselect} = $action;
        }

        # Add button config if available
        $state_info->{button}->{$action} = $button->{$option} if $button->{$option};
    }

    # add button markup (head)
    $state_info->{button}->{_head} = $button->{_head} if $button->{_head};

    return {
        activity => $action_info,
        state => $state_info,
    };
}


=head2 can_create_workflow (type, role)

Check if the given role (default is the session role) is allowed to
create workflows of the given type. Returns true/false and throws an
exception if the workflow type is unknown or missing.

=cut

sub can_create_workflow {

    my $self  = shift;
    my $type  = shift;
    my $role  = shift || CTX('session')->data->role || 'Anonymous';
    ##! 1: 'start'

    OpenXPKI::Exception->throw(
        message => 'No type was given'
    ) unless($type);

    my $conn = CTX('config');

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_UI_WORKFLOW_CREATE_UNKNOWN_TYPE'
    ) unless($conn->exists([ 'workflow', 'def', $type]));

    # if creator is set then access is allowed
    return ($conn->exists([ 'workflow', 'def', $type, 'acl', $role, 'creator' ]));

}

=head2 can_access_workflow

Helper method to evaluate the acl given in the workflow config against
against a concrete instance. Expects two hashes to be passed, the first
hash represents the workflow instance, the second the entity that
requests access.

The first hash must include type and creator, tenant must be set to
evaluate tenant based rules.

The second hash is optional, if present it must have the keys user,
role and tenant (if enabled). If omited user/role is read from the
session and tenant is checked against the current users tenant list.

Returns 1 if the user can access the workflow. Return undef if no acl
is defined for the current role and 0 if an acl was found but does not
authorize the current user.

Will thrown an exception if a mandatory parameter was not passed.

=cut

sub can_access_workflow {

    ##! 1: 'start'
    my ($self, $instance, $user) = @_;

    OpenXPKI::Exception->throw(
        message => 'No type given to Workflow::Factory::can_access_workflow',
    ) unless($instance->{type});

    OpenXPKI::Exception->throw(
        message => 'No creator given to Workflow::Factory::can_access_workflow',
    ) unless($instance->{creator});

    ##! 64: $instance
    $user //= {
        user => CTX('session')->data->user,
        role => (CTX('session')->data->has_role ? CTX('session')->data->role : 'Anonymous'),
        tenant => ''
    };
    ##! 64: $user

    my @allowed_creator = CTX('config')->get_scalar_as_list([ 'workflow', 'def', $instance->{type}, 'acl', $user->{role}, 'creator' ]);
    ##! 32: 'Rules ' . Dumper \@allowed_creator
    return unless (@allowed_creator);

    my $is_allowed = 0;
    foreach my $allowed_creator_re (@allowed_creator) {
        ##! 32: "Checking $allowed_creator_re"
        # Access only to own workflows - check session user against creator
        if ($allowed_creator_re eq 'self') {
            $is_allowed = ($instance->{creator} eq $user->{user});

        # No access to own workflows
        } elsif ($allowed_creator_re eq 'others') {
            $is_allowed = ($instance->{creator} ne $user->{user});

        # access by tenant
        } elsif ($allowed_creator_re eq 'tenant') {

            # useless check if the workflow has no tenant
            next unless(defined $instance->{tenant});

            # tenant is given, we check for an exact match
            if ($user->{tenant}) {
                $is_allowed = ($instance->{tenant} eq $user->{tenant});

            # tenant is DEFINED = use tenant handler to check
            } elsif (defined $user->{tenant}) {
                $is_allowed = CTX('api2')->can_access_tenant( tenant => $instance->{tenant} );
            }
            # no tenant check if tenant is not set - this avoids using
            # the session tenant handler with a explicit user/role given

        # access to any workflow
        } elsif ($allowed_creator_re eq 'any') {
            $is_allowed = 1;

        # Access by Regex - check
        } else {
            $is_allowed = ($instance->{creator} =~ qr/$allowed_creator_re/);
        }
        ##! 64: "$allowed_creator_re / " . ($is_allowed ? '1' : '0')
        last if $is_allowed;
    }
    ##! 16: "Final result: $is_allowed"
    return $is_allowed;
}

=head2 can_access_handle

Check if a user/role can access a certain property (history, techlog)
or handle (resume, wakeup) for a given workflow type.

Returns boolean true/false or undef if no permissions are set.

=cut

sub can_access_handle {

    my ( $self, $type, $action, $role ) = @_;

    OpenXPKI::Exception->throw(
        message => 'Unknown handle/property given to can_access_handle',
        params  => { 'action' => $action }
    ) unless ($action =~ m{\A(fail|resume|reset|wakeup|history|techlog|attribute|context|archive|delete)\z});

    OpenXPKI::Exception->throw(
        message => 'None or unknown workflow type was given',
        params => { type => ($type  // '<undef>')}
    ) unless($type && CTX('config')->exists([ 'workflow', 'def', $type]));

    $role //= (CTX('session')->data->role || 'Anonymous');
    return (CTX('config')->get([ 'workflow', 'def', $type, 'acl', $role, $action ]));

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
checks before returning the workflow to the caller.

All methods return an object of class OpenXPKI::Server::Workflow, which is derived
from Workflow base class and implements the pause/resume-features. see there for details.
