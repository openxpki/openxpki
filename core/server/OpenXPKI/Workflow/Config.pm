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
    lazy => 1, # This is fundamental! (race condition within loader -> empty ref)
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

        # Add workflow defined validators
        my @validator_names = $conn->get_keys(['workflow','def', $wf_name, 'validator']);
        foreach my $validator_name (@validator_names) {
            $self->__process_validator(['workflow','def', $wf_name, 'validator', $validator_name ]);
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

    # Validators
    my @validator_names = $conn->get_keys(['workflow','global', 'validator']);
    foreach my $validator_name (@validator_names) {
        $self->__process_validator(['workflow','global', 'validator', $validator_name ]);
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

    my $wf_persister = $conn->get( [ 'workflow', 'def', $wf_name , 'head', 'persister' ] );
    if ($wf_persister) {
        $workflow->{persister}  = $wf_persister;
    }

    my $wf_prefix = $conn->get( [ 'workflow', 'def', $wf_name , 'head', 'prefix' ] );

    my @states = $conn->get_keys( ['workflow', 'def', $wf_name, 'state' ] );

    # The FAILURE state is required for the autofail feature
    if (!grep /FAILURE/, @states) {
        push @states, 'FAILURE';
    }

    foreach my $state_name (@states) {

        # We are not interessted in eye candy, just the logic
        # action attribute has a list/scalar with a combo string
        # left hand ist action name, right hand the target state
        # action: run_test1 > PENDING

        my @actions;
        my @action_items = $conn->get_scalar_as_list(['workflow', 'def', $wf_name, 'state', $state_name, 'action' ] );

        foreach my $action_item (@action_items) {

            my ($global, $action_name, $next_state, $nn, $conditions) =
                ($action_item =~ m{ \A (global_)?([\w\s]+\w)\s*>\s*(\w+)(\s*\?\s*([!\w\s]+))? }xs);

            # Support for internal chaining of actions, sep. by space
            my @inline_action = split /\s+/, $action_name;
            $action_name = shift @inline_action;

            CTX('log')->workflow()->debug("Adding action: $action_name -> $next_state");


            my $prefix;
            # As actions share a global namespace, we add a prefix to their names
            # except if the action has the "global" prefix
            if ($global) {
                $prefix = 'global_';
            } else {
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
                    # Check for opposite
                    my $flag_opposite = '';
                    if ($cond =~ /^!/) {
                        $flag_opposite = '!';
                        $cond = substr($cond,1);
                    }

                    # Conditions can have another prefix then the action, so check for it
                    if ($cond !~ /^global_/) {
                        $cond = $wf_prefix.'_'.$cond;
                    }

                    # Merge opposite and prefixed name
                    push @{$item->{condition}}, { name => $flag_opposite.$cond }

                }
            }

            # TODO - this is experimental!
            if (scalar @inline_action) {

                CTX('log')->workflow()->debug("Auto append inline actions: " . join (" > ", @inline_action));


                my $generator_name = uc($state_name.'_'.$item->{name}).'_%01d';
                my $generator_index = 0;

                # point the first action to the first auto generated state
                $item->{resulting_state} = sprintf($generator_name, $generator_index);

                while (my $auto_action = shift @inline_action) {

                    if ($auto_action !~ /^global_/) {
                        $auto_action = $wf_prefix.'_'.$auto_action;
                    }

                    push @{$workflow->{state}}, {
                        name => sprintf($generator_name, $generator_index++),
                        autorun => 'yes',
                        action => [{
                            name => $auto_action,
                            resulting_state => (scalar @inline_action ? sprintf($generator_name, $generator_index) : $next_state),
                        }]
                    };
                }
            }

            push @actions, $item;

        } # end actions

        my $state = {
            name => $state_name,
            action => \@actions
        };

        # Autorun
        my $is_autorun = $conn->get(['workflow', 'def', $wf_name, 'state', $state_name, 'autorun' ] );
        if ($is_autorun && $is_autorun =~ m/(1|true|yes)/) {
            $state->{autorun} = 'yes';
        }
        push @{$workflow->{state}}, $state;

    } # end states

    ##! 32: 'Workflow Config ' . Dumper $workflow

    push @{$self->_workflow_config()->{workflow}}, $workflow;

    CTX('log')->workflow()->info("Adding workflow: $wf_name");


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

    CTX('log')->workflow()->debug("Adding action definition: " . join (".", @path));


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

        my @item_path;
        # Fields can be defined local or global (only actions inside workflow)
        if ($wf_name) {
            @item_path = ( 'workflow', 'def', $wf_name, 'field', $field_name );
            if (!$conn->exists( \@item_path )) {
                @item_path = ( 'workflow', 'global', 'field', $field_name );
            }
        } else {
            @item_path = ( 'workflow', 'global', 'field', $field_name );
        }

        my $context_key = $conn->get( [ @item_path, 'name' ] );
        if (!$context_key) {
            OpenXPKI::Exception->throw(
                message => 'Field name used in workflow config is not defined',
                params => {
                    workflow => $wf_name,
                    action => $action_name,
                    field => $field_name,
                }
            );
        }

        # We just need the name and the required flag for the workflow engine
        # anything else is UI control only and pulled from the connector at runtime
        my $required = $conn->get( [ @item_path, 'required' ] );
        my $is_required = (defined $required && $required =~ m/(yes|1)/i);

        CTX('log')->workflow()->debug("Adding field $field_name / $context_key");


        # Push to the field list for the action
        push @fields, { name => $context_key, is_required => $is_required ? 'yes' : 'no' };

    }

    my @validators = ();
    # Attach validators - name => $name, arg  => [ $value ]
    my @valid = $conn->get_scalar_as_list( [ @path, 'validator' ] );
    foreach my $valid_name (@valid) {

        my @item_path;
        # Inside workflow, check if validator has global prefix
        if ($valid_name =~ /^global_(\S+)/) {
            @item_path = ( 'workflow', 'global', 'validator', $1 );
        } else {
            # Are we in a global definiton?
            if ($wf_name) {
                @item_path = ( 'workflow', 'def', $wf_name, 'validator', $valid_name );
            } else {
                @item_path = ( 'workflow', 'global', 'validator', $valid_name );
            }
             # Prefix is global_ in global defs, so matches both cases
            $valid_name = $prefix.$valid_name;
        }

        # Validator can have an argument list, params are handled by the global implementation definiton!
        my @extra_args = $conn->get_scalar_as_list( [ @item_path, 'arg' ] );

        ##! 16: 'Validator path ' . Dumper \@item_path
        ##! 16: 'Validator arguments ' . Dumper @extra_args

        CTX('log')->workflow()->debug("Adding validator $valid_name with args " . (join", ", @extra_args));


        # Push to the field list for the action
        push @validators, { name => $valid_name,  arg => \@extra_args };

    }

    my $action = {
        name => $prefix.$action_name,
        class => $action_class,
        field => \@fields,
        validator => \@validators
    };

    # Additional params are read from the object itself
    my $param = $conn->get_hash([ @path, 'param' ] );
    map {  $action->{$_} = $param->{$_} } keys %{$param};

    CTX('log')->workflow()->trace("Adding action " . (Dumper $action));


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

    CTX('log')->workflow()->debug("Adding condition " . join(".", @path));


    my $wf_name;
    # check if its a global or workflow path to determine prefix
    if ($path[1] eq 'def') {
        $wf_name = $path[2];
        $prefix = $conn->get( ['workflow', 'def', $wf_name, 'head', 'prefix' ] );
        $prefix .= '_';
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
    my $param = $conn->get_hash([ @path, 'param' ] );
    my @param = map { { name => $_, value => $param->{$_} } } keys %{$param};

    if (scalar @param) {
        $condition->{param} = \@param;
    }

    CTX('log')->workflow()->trace("Adding condition " . (Dumper $condition));


    push @{$self->_workflow_config()->{condition}}, $condition;

    return $condition;

}


=head2 __process_validator

Add the validator implementation details to the global definition.
This includes class, class params and parameters.

=cut
sub __process_validator {

    my $self = shift;
    my $path = shift;

    my $conn = $self->_config();

    # Get the prefix
    my $prefix;
    my @path = @{$path};

    CTX('log')->workflow()->debug("Adding validator " . join(".", @path));


    my $wf_name;
    # check if its a global or workflow path to determine prefix
    if ($path[1] eq 'def') {
        $wf_name = $path[2];
        $prefix = $conn->get( ['workflow', 'def', $wf_name, 'head', 'prefix' ] );
        $prefix .= '_';
    } else {
        $prefix = 'global_';
    }

    my $validator_name = $path[-1];

    # Get the implementation class
    my $validator_class = $conn->get([ @path, 'class' ] );

    my $validator = {
        name => $prefix.$validator_name,
        class => $validator_class,
    };

    # Get params
    my $param = $conn->get_hash([ @path, 'param' ] );
    my @param = map { { name => $_, value => $param->{$_} } } keys %{$param};

    if (scalar @param) {
        $validator->{param} = \@param;
    }

    CTX('log')->workflow()->trace("Adding validator " . (Dumper $validator));


    push @{$self->_workflow_config()->{validator}}, $validator;

    return $validator;

}
1;

__END__;
