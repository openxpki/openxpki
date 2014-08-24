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

        # Add workflow defined actions, also handles conditions and validators
        my @action_names = $conn->get_keys(['workflow','def', $wf_name, 'action']);
        foreach my $action_name (@action_names) {
            $self->__process_action($action_name, $wf_name);
        }

    }

    # Finally add the global actions
    my @action_names = $conn->get_keys(['workflow','global', 'action']);
    foreach my $action_name (@action_names) {
        $self->__process_action($action_name);
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

            my ($global, $action_name, $next_state) = ($action_item =~ m{ \A (global_)?([\w\d]+)\s*>\s*([\w\d]+) }xs);

            CTX('log')->log(
                MESSAGE  => "Adding Action: $action_name -> $next_state",
                PRIORITY => 'debug',
                FACILITY => 'workflow',
            );

            my @conditions;
            my $prefix;
            # As actions share a global namespace, we add a prefix to their names
            # except if the action has the "global" prefix
            if ($global) {
                @conditions = $conn->get_scalar_as_list( [ 'workflow', 'global', 'action', $action_name, 'condition' ] );
                $prefix = 'global_';
            } else {
                @conditions = $conn->get_scalar_as_list( [ 'workflow', 'def', $wf_name, 'action', $action_name, 'condition' ] );
                $prefix = $wf_prefix.'_';
            }

            my $item = {
                name => $prefix.$action_name,
                resulting_state => $next_state
            };
            if (scalar @conditions) {
                $item->{condition} = [];
                map {  push @{$item->{condition}}, { name => $prefix.$_ } } @conditions;
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
    my $action_name = shift;
    my $wf_name = shift;

    my $conn = $self->_config();

    # Get the prefix
    my $prefix;
    my @path;
    if ($wf_name) {
        @path = ( 'workflow', 'def', $wf_name, 'action', $action_name );
        $prefix = $conn->get( ['workflow', 'def', $wf_name , 'head', 'prefix' ] );
        $prefix .= '_';
    } else {
        @path = ( 'workflow', 'global', 'action', $action_name );
        $prefix = 'global_';
    }


    # Get the implementation class
    my $action_class = $conn->get([ @path, 'class' ] );

    my $action = {
        name => $prefix.$action_name,
        class => $action_class
    };

    push @{$self->_workflow_config()->{action}}, $action;

    return $action;

}

1;

__END__;