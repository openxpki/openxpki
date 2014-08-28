## OpenXPKI::Workflow::Config
##
package OpenXPKI::Workflow::Config;

use strict;
use warnings;

use Workflow 1.39;
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;

use Moose;

has '_workflow_config' => (
    is => 'rw',
    isa => 'HashRef',
    required => 0,
    reader => 'workflow_config',
    builder => '_build_workflow_config'
);

has '_config' => (
    is => 'rw',
    isa => 'Object',
    required => 0,
    default => sub { return CTX('config'); }
);

sub _build_workflow_config {

    my $self = shift;

    my $conn = $self->_config();

    # Init the structure
    $self->_workflow_config({ condition => [], validator => [], action =>[], workflow => [], persister => [] });

    # Add Persisters
    my @persister = $conn->get_keys('workflow.persister');
    foreach my $persister (@persister) {
        my $conf = $conn->get_hash(['workflow','persister', $persister]);
        $conf->{name} = $persister;
        push @{$self->_workflow_config()->{persister}}, $conf;
    }

    # Add workflows
    my @workflow_def = $conn->get_keys('workflow.def');
    foreach my $wf_name (@workflow_def) {
        # The main workflow definiton (the flow rules)
        $self->__process_workflow($wf_name);

        # Add workflow defined actions
        my @action_names = $conn->get_keys(['workflow','def', $wf_name, 'action']);
        foreach my $action_name (@action_names) {
            $self->__process_action(['workflow','def', $wf_name, 'action', $action_name ]);
        }

        # Add workflow defined conditions
        my @condition_names = $conn->get_keys(['workflow','def', $wf_name, 'condition']);
        foreach my $condition_name (@condition_names) {
            $self->__process_condition(['workflow','def', $wf_name, 'condition', $condition_name ]);
        }

    }

    # Finally add the global actions
    my @action_names = $conn->get_keys(['workflow','global', 'action']);
    foreach my $action_name (@action_names) {
        $self->__process_action(['workflow','global', 'action', $action_name]);
    }

    # And conditions
    my @condition_names = $conn->get_keys(['workflow','global', 'condition']);
    foreach my $condition_name (@condition_names) {
        $self->__process_condition(['workflow','global', 'condition', $condition_name ]);
    }

    return $self->_workflow_config

}

sub __process_workflow {

    my $self = shift;
    my $wf_name = shift;

    my $workflow = {
        type => $wf_name,
        persister => 'OpenXPKI',
        state => []
    };

    my $conn = $self->_config();

    my $wf_prefix = $conn->get( [ 'workflow', 'def', $wf_name , 'head', 'prefix' ] );

    my @states = $conn->get_keys( ['workflow', 'def', $wf_name, 'state' ] );

    foreach my $state_name (@states) {

        # We are not interessted in eye candy, just the logic
        # action attribute has a list/scalar with a combo string
        # left hand ist action name, right hand the target state
        # action: run_test1 > PENDING

        my @actions;
        my @action_items = $conn->get_scalar_as_list(['workflow', 'def', $wf_name, 'state', $state_name, 'action' ] );

        foreach my $action_item (@action_items) {

            my ($global, $action_name, $next_state, $nn, $conditions) =
                ($action_item =~ m{ \A (global_)?(\w+)\s*>\s*(\w+)(\s*\?\s*([!\w\s]+))? }xs);

            CTX('log')->log(
                MESSAGE  => "Adding Action: $action_name -> $next_state",
                PRIORITY => 'debug',
                FACILITY => 'workflow',
            );

            my $prefix;
            # As actions share a global namespace, we add a prefix to their names
            # except if the action has the "global" prefix
            if ($global) {
                #@conditions = $conn->get_scalar_as_list( [ 'workflow', 'global', 'action', $action_name, 'condition' ] );
                $prefix = 'global_';
            } else {
                #@conditions = $conn->get_scalar_as_list( [ 'workflow', 'def', $wf_name, 'action', $action_name, 'condition' ] );
                $prefix = $wf_prefix.'_';
            }

            my $item = {
                name => $prefix.$action_name,
                resulting_state => $next_state
            };
            if ($conditions) {
                my @conditions = split /\s+/, $conditions;
                $item->{condition} = [];
                # we need to insert the prefix and take care of the ! mark
                foreach my $cond (@conditions) {
                    if ($cond =~ /^!/) {
                        push @{$item->{condition}}, { name => '!'.$prefix.substr($cond,1) }
                    } else {
                        push @{$item->{condition}}, { name => $prefix.$_ }
                    }
                }
            }
            push @actions, $item;
        } # end actions

        push @{$workflow->{state}}, {
            name => $state_name,
            action => \@actions
        };
    } # end states

    ##! 32: 'Workflow Config ' . Dumper $workflow

    push @{$self->_workflow_config()->{workflow}}, $workflow;

    CTX('log')->log(
        MESSAGE  => "Adding workflow: $wf_name",
        PRIORITY => 'debug',
        FACILITY => 'workflow',
    );

    return $workflow;

}


=head2 __process_action

Add the action implementation details to the global action definition.
This includes class, class params, fields and validators.

=cut
sub __process_action {

    my $self = shift;
    my $path = shift;

    my $conn = $self->_config();

    # Get the prefix
    my $prefix;
    my @path = @{$path};

    my $wf_name;
    # check if its a global or workflow path to determine prefix
    if ($path[1] eq 'def') {
        $wf_name = $path[2];
        $prefix = $conn->get( ['workflow', 'def', $wf_name, 'head', 'prefix' ] );
        $prefix .= '_';
    } else {
        $prefix = 'global_';
    }

    my $action_name = $path[-1];

    # Get the implementation class
    my $action_class = $conn->get([ @path, 'class' ] );

    # Get input fields
    my @input = $conn->get_scalar_as_list( [ @path, 'input' ] );
    my @fields = ();
    foreach my $field_name (@input) {

        my @field_path;
        # Fields can be defined local or global (only actions inside workflow)
        if ($wf_name) {
            @field_path = ( 'workflow', 'def', $wf_name, 'field', $field_name );
            if (!$conn->exists( @field_path )) {
                @field_path = ( 'workflow', 'global', 'field', $field_name );
            }
        } else {
            @field_path = ( 'workflow', 'global', 'field', $field_name );
        }

        my $context_key = $conn->get( [ @field_path, 'name' ] );
        if (!$context_key) {
            OpenXPKI::Exception->throw(
                message => 'Field name used in workflow config is not defined',
                params => { workflow => $wf_name, action => $action_name, field => $field_name }
            );
        }

        # We just need the name and the required flag for the workflow engine
        # anything else is UI control only and pulled from the connector at runtime
        my $required = $conn->get( [ @field_path, 'required' ] );
        my $is_required = (defined $required && $required =~ m/(yes|1)/i);

        # Push to the field list for the action
        push @fields, { name => $context_key, is_required => $is_required ? 'yes' : 'no' };

    }


    my $action = {
        name => $prefix.$action_name,
        class => $action_class,
        field => \@fields
    };

    push @{$self->_workflow_config()->{action}}, $action;

    return $action;

}

=head2 __process_condition

Add the condition implementation details to the global definition.
This includes class, class params and parameters.

=cut
sub __process_condition {

    my $self = shift;
    my $path = shift;

    my $conn = $self->_config();

    # Get the prefix
    my $prefix;
    my @path = @{$path};

    my $wf_name;
    # check if its a global or workflow path to determine prefix
    if ($path[1] eq 'def') {
        $wf_name = $path[2];
        $prefix = $conn->get( ['workflow', 'def', $wf_name, 'head', 'prefix' ] );
    } else {
        $prefix = 'global_';
    }

    my $condition_name = $path[-1];

    # Get the implementation class
    my $condition_class = $conn->get([ @path, 'class' ] );

    my $condition = {
        name => $prefix.$condition_name,
        class => $condition_class,
    };

    # Get params
    my $param = $conn->get([ @path, 'param' ] );
    my @param = map { { name => $_, value => $param->{$_} } } keys %{$param};

    if (scalar @param) {
        $condition->{param} = \@param;
    }

    push @{$self->_workflow_config()->{condition}}, $condition;

    return $condition;

}
1;

__END__;