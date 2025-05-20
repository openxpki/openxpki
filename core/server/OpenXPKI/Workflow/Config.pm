package OpenXPKI::Workflow::Config;
use OpenXPKI -class;

# Core modules
use List::Util qw( any );

# CPAN modules
use Workflow 1.39;

# Project modules
use OpenXPKI::Server::Context qw( CTX );


has '_workflow_config' => (
    is => 'rw',
    isa => 'HashRef',
    reader => 'workflow_config',
    lazy => 1,
    builder => '_build_workflow_config',
);

has '_config' => (
    is => 'rw',
    isa => 'Object',
    lazy => 1, # This is fundamental! (race condition within loader -> empty ref)
    default => sub { return CTX('config'); }
);

has 'logger' => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    default => sub { return CTX('log')->workflow(); }
);

sub _build_workflow_config {

    ##! 1: 'start config'
    my $self = shift;

    my $conn = $self->_config();

    # Fetch serialized workflow definition from config layer
    if (!$conn->exists('workflow.def')) {
        my $pki_realm = CTX('session')->data->pki_realm;
        OpenXPKI::Exception->throw(
            message => 'No workflow configuration found for current realm',
            params => {
                realm => $pki_realm,
                config_path => "realm.$pki_realm.workflow.def",
            },
        );
    }

    # Init structure
    my $wf_conf = { condition => [], validator => [], action =>[], workflow => [], persister => [] };

    # Add persisters
    my @persister = sort $conn->get_keys('workflow.persister');
    foreach my $persister (@persister) {
        my $conf = $conn->get_hash(['workflow','persister', $persister]);

        # Additional parameter below 'param' sub node are shifted on leve up
        if (my $param = delete $conf->{param}) {
            $conf = { $param->%*, $conf->%* };
        }

        $conf->{name} = $persister;

        push @{$wf_conf->{persister}}, $conf;
    }

    my @global_fields = $self->__process_fields(['workflow', 'global', 'field']);

    # Add workflows
    my %known_prefixes;
    my @workflow_def = sort $conn->get_keys('workflow.def');
    foreach my $wf_name (@workflow_def) {
        # The main workflow definiton (the flow rules)
        push @{$wf_conf->{workflow}}, $self->__process_workflow($wf_name);

        my $prefix = $conn->get( ['workflow', 'def', $wf_name, 'head', 'prefix'] );

        OpenXPKI::Exception->throw(
            message => "Duplicate workflow prefix '$prefix' - unable to load workflow configuration",
            params => { workflow_a => $known_prefixes{$prefix}, workflow_b => $wf_name }
        ) if defined $known_prefixes{$prefix};
        $known_prefixes{$prefix} = $wf_name;

        $prefix = $prefix . '_';

        # Workflow defined actions, conditions, validators
        my @wf_fields = $self->__process_fields(['workflow', 'def', $wf_name, 'field']);
        push @{$wf_conf->{action}},    $self->__process_actions(   ['workflow','def', $wf_name, 'action'], $prefix, $wf_name, [@wf_fields, @global_fields]);
        push @{$wf_conf->{condition}}, $self->__process_conditions(['workflow','def', $wf_name, 'condition'], $prefix);
        push @{$wf_conf->{validator}}, $self->__process_validators(['workflow','def', $wf_name, 'validator'], $prefix);
    }

    # Global actions, conditions, validators
    push @{$wf_conf->{action}},    $self->__process_actions(   ['workflow','global', 'action'], 'global_', undef, \@global_fields);
    push @{$wf_conf->{condition}}, $self->__process_conditions(['workflow','global', 'condition'], 'global_');
    push @{$wf_conf->{validator}}, $self->__process_validators(['workflow','global', 'validator'], 'global_');
    push @{$wf_conf->{validator}}, {
        name => '_internal_basic_field_type',
        class => 'OpenXPKI::Server::Workflow::Validator::BasicFieldType'
    };

    # check for duplicate names
    foreach my $class (('action','condition','validator')) {
        my %known_item;
        foreach my $item (@{$wf_conf->{$class}}) {
            my $name = $item->{name};
            OpenXPKI::Exception->throw(
                message => "Duplicate $class name '$name' - unable to load workflow configuration",
            ) if defined $known_item{$name};
            $known_item{$name} = 1;
        }
    }

    return $wf_conf;
}

sub __process_workflow {
    my ($self, $wf_name) = @_;

    my $workflow = {
        type => $wf_name,
        persister => 'OpenXPKI',
        observer => [
            { class => 'OpenXPKI::Server::Workflow::Observer::AddExecuteHistory' },
            { class => 'OpenXPKI::Server::Workflow::Observer::Log' },
        ],
        state => []
    };

    my $conn = $self->_config();
    my @cfg_wf_head = ('workflow', 'def', $wf_name, 'head');
    my @cfg_wf_state = ('workflow', 'def', $wf_name, 'state');

    my $wf_persister = $conn->get( [ @cfg_wf_head, 'persister' ] );
    $workflow->{persister} = $wf_persister if $wf_persister;

    my $wf_prefix = $conn->get( [ @cfg_wf_head, 'prefix' ] );

    if (!$wf_prefix || ($wf_prefix =~ /[^a-z0-9]/)) {
        OpenXPKI::Exception->throw(
            message => 'Workflow prefix must be set and contain no other chars as a-z and 0-9',
            params => {
                name => $wf_name,
                prefix => $wf_prefix
            }
        );
    }

    my @states = sort $conn->get_keys( \@cfg_wf_state );

    # The FAILURE state is required for the autofail feature
    push @states, 'FAILURE' unless (grep /FAILURE/, @states);

    foreach my $state_name (@states) {
        # We are not interested in eye candy, just the logic.
        # 'action' attribute has a list/scalar with a combo string.
        # Left hand is action name, right hand the target state:
        #   action: run_test1 > PENDING

        my @actions;
        my @action_items = $conn->get_scalar_as_list([ @cfg_wf_state, $state_name, 'action' ] );

        foreach my $action_item (@action_items) {
            my ($auto, $global, $action_name, $next_state, $nn, $conditions) =
                ($action_item =~ m{ \A (\W?)(global_)?([\w\s]+\w)\s*>\s*(\w+)(\s*\?\s*([!\w\s]+))? }xs);

            # Support for internal chaining of actions, sep. by space
            my @inline_action = split /\s+/, $action_name;
            $action_name = shift @inline_action;

            $self->logger()->debug("Adding action: $action_name -> $next_state");

            # As actions share a global namespace, we add a prefix to their names
            # except if the action has the "global" prefix
            my $prefix = $global ? 'global_' : "${wf_prefix}_";

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

                $self->logger()->debug("Auto append inline actions: " . join (" > ", @inline_action));

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
        my $is_autorun = $conn->get([ @cfg_wf_state, $state_name, 'autorun' ] );
        if ($is_autorun && $is_autorun =~ m/(1|true|yes)/) {
            $state->{autorun} = 'yes';
        }
        push @{$workflow->{state}}, $state;

    } # end states

    $self->logger()->info("Adding workflow: $wf_name");

    ##! 32: 'Workflow Config ' . Dumper $workflow
    return $workflow;
}

sub __process_fields {
    my ($self, $root_path) = @_;
    my @result = ();
    my $conn = $self->_config();

    for my $field_name (sort $conn->get_keys($root_path)) {
        my @path = (@{$root_path}, $field_name);
        ##! 16: 'Processing field ' . join (".", @path)

        my $context_key = $conn->get([ @path, 'name' ]) || $field_name;
        my $type = $conn->get( [ @path, 'type' ] ) || '';

        my $field = {
            name => $field_name,
            context_key => $context_key,
            type => $type,
        };
        #
        # check if validator is needed
        #
        my $is_array = ($conn->exists( [ @path, 'min' ] ) || $conn->exists( [ @path, 'max' ] ));
        # As the upstream "required" validator accepts the empty string as
        # true which we want to be "false" we do not set the required flag
        # but use our own field type validator
        my $required = $conn->get( [ @path, 'required' ] );
        my $is_required = (defined $required && $required =~ m/(yes|1)/i);
        my $match = $conn->get( [ @path, 'match' ] ) || '';

        ##! 64: "Adding basic validator for $context_key with $type:$is_array:$is_required:$match"
        # this string will be interpreted in OpenXPKI::Server::Workflow::Validator::BasicFieldType
        $field->{basic_validator} = sprintf ("%s:%s:%01d:%01d:%s", $context_key, $type, $is_array, $is_required, $match);

        push @result, $field;
    }
    return @result;
}

=head2 __process_actions

Add the action implementation details to the global action definition.
This includes class, class params, fields and validators.

=cut
sub __process_actions {
    my ($self, $root_path, $prefix, $wf_name, $fields) = @_;
    my @result = ();
    my $conn = $self->_config();

    for my $action_name (sort $conn->get_keys($root_path)) {
        my @path = (@{$root_path}, $action_name);
        $self->logger()->debug("Adding action definition: " . join (".", @path));
        ##! 16: 'Processing action ' . join (".", @path)

        # Get the implementation class
        my $action_class = $conn->get([ @path, 'class' ] );

        # Get input fields
        my @input = $conn->get_scalar_as_list( [ @path, 'input' ] );
        my @fields = ();

        my @basic_validator = ();
        foreach my $field_name (@input) {
            # it is important to use grep on the sorted list here as $fields
            # contains the local and global definitions so there might be a
            # "wrong" definition in a later position.
            my ($field) = grep { $_->{name} eq $field_name } @{$fields};
            if (!$field) {
                OpenXPKI::Exception->throw(
                    message => 'Field name used in workflow config is not defined',
                    params => {
                        workflow => $wf_name,
                        action => $action_name,
                        field => $field_name,
                    }
                );
            }
            push @basic_validator, $field->{basic_validator} if $field->{basic_validator}; # 'basic_validator' is set in __process_fields()
            push @fields, {
                name => $field->{context_key},
                is_required => 'no',
                class => 'OpenXPKI::Server::Workflow::Field', # Workflow::Action::InputField always sets type to "basic"
                type => $field->{type},
            };
            $self->logger()->debug("- adding field $field_name / $field->{context_key}");
        }

        my @validators = ();

        ##! 32: 'Basic validator ' . Dumper \@basic_validator

        # add basic validator - if required (class: OpenXPKI::Server::Workflow::Validator::BasicFieldType)
        push @validators, { name => '_internal_basic_field_type', arg => \@basic_validator } if (scalar @basic_validator > 0);

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

            $self->logger()->debug("Adding validator $valid_name with args " . (join", ", @extra_args));


            # Push to the field list for the action
            push @validators, { name => $valid_name,  arg => \@extra_args };

        }

        my $action = {
            name => $prefix.$action_name,
            class => $action_class,
            field => \@fields,
            validator => \@validators,
        };

        # Additional params are read from the object itself
        my $param = $conn->get_hash([ @path, 'param' ] );
        $action->{$_} = $param->{$_} for keys $param->%*;

        $self->logger()->trace("Adding action " . (Dumper $action)) if $self->logger->is_trace;
        ##! 32: 'Action definition: ' . Dumper($action)

        push @result, $action;
    }
    return @result;
}

=head2 __process_conditions

Add the condition implementation details to the global definition.
This includes class, class params and parameters.

=cut
sub __process_conditions {
    my ($self, $root_path, $prefix) = @_;
    my @result = ();
    my $conn = $self->_config();

    my @local_cond_names = sort $conn->get_keys($root_path);

    for my $condition_name (@local_cond_names) {
        my @path = (@{$root_path}, $condition_name);
        $self->logger()->debug("Adding condition " . join(".", @path));
        ##! 16: 'Processing condition ' . join (".", @path)

        # Get the implementation class
        my $condition_class = $conn->get([ @path, 'class' ] );

        # FIXME - remove once upstream Workflow::Condition::Evaluate got rid of the "Safe" module
        $condition_class = "OpenXPKI::Server::Workflow::Condition::Evaluate" if "Workflow::Condition::Evaluate" eq $condition_class;

        my $condition = {
            name => $prefix.$condition_name,
            class => $condition_class,
        };

        # Get params
        my $param = $conn->get_hash([ @path, 'param' ] );
        my @param = map { { name => $_, value => $param->{$_} } } sort keys %{$param};

        if (scalar @param) {
            $condition->{param} = \@param;
        }

        $self->logger()->trace("Adding condition " . (Dumper $condition)) if $self->logger->is_trace;
        push @result, $condition;
    }

    #
    # Auto-prepend workflow prefix to nested condition names
    #
    my $normalize_array = sub { # from Workflow::Base
        my ( $ref_or_item ) = @_;
        return () unless ($ref_or_item);
        return ( ref $ref_or_item eq 'ARRAY' ) ? @{$ref_or_item} : ($ref_or_item);
    };

    # Add workflow prefix to referenced conditions' name unless it
    # starts with "global_" or already has the prefix prepended.
    my $auto_prepend_prefix = sub {
        my ( $cond_name, $ref_name ) = @_;
        my $not = ($ref_name =~ s/^!//) ? '!' : '';
        # don't touch "global_" or already prefixed names
        return $not.$ref_name if $ref_name =~ /^(global_|$prefix)/;
        # prepend workflow prefix if the given condition is a known local name
        return $not.$prefix.$ref_name if any { $ref_name eq $_ } @local_cond_names;
        # otherwise it must be a fault or a condition from another workflow
        OpenXPKI::Exception->throw(
            message => "Nested condition in '$cond_name' references unkown condition '$ref_name'",
        );
    };

    for my $cond (@result) {
        # process "condition" parameter (may be scalar or array)
        if (any { $cond->{class} eq "Workflow::Condition::$_" } qw( CheckReturn GreedyOR LazyAND LazyOR )) {
            for my $param (grep { $_->{name} eq 'condition' } $cond->{param}->@*) {
                my @refs = $normalize_array->($param->{value});
                $param->{value} = [ map { $auto_prepend_prefix->($cond->{name}, $_ ) } @refs ];
            }
        }
        # process "condition1", "condition2" etc. (scalar)
        if (any { $cond->{class} eq "Workflow::Condition::$_" } qw( GreedyOR LazyAND LazyOR )) {
            for my $param (grep { $_->{name} =~ /^condition\d/ } $cond->{param}->@*) {
                $param->{value} = $auto_prepend_prefix->($cond->{name}, $param->{value});
            }
        }
    }

    return @result;
}

=head2 __process_validators

Add the validator implementation details to the global definition.
This includes class, class params and parameters.

=cut
sub __process_validators {
    my ($self, $root_path, $prefix) = @_;
    my @result = ();
    my $conn = $self->_config();

    for my $validator_name (sort $conn->get_keys($root_path)) {
        my @path = (@{$root_path}, $validator_name);
        $self->logger()->debug("Adding validator " . join(".", @path));
        ##! 16: 'Processing validator ' . join (".", @path)

        # Get the implementation class
        my $validator_class = $conn->get([ @path, 'class' ] );

        my $validator = {
            name => $prefix.$validator_name,
            class => $validator_class,
        };

        # Get params
        my $param = $conn->get_hash([ @path, 'param' ] );
        my @param = map { { name => $_, value => $param->{$_} } } sort keys %{$param};

        if (scalar @param) {
            $validator->{param} = \@param;
        }

        $self->logger()->trace("Adding validator " . (Dumper $validator)) if $self->logger->is_trace;
        push @result, $validator;
    }
    return @result;
}

__PACKAGE__->meta->make_immutable;

__END__;
