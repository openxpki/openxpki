package OpenXPKI::Server::API2::Plugin::Workflow::create_workflow_instance;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::create_workflow_instance

=cut
# Core modules
use Scalar::Util 'blessed';

# CPAN modules
use Try::Tiny;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;



=head1 COMMANDS

=head2 create_workflow_instance

Create a new workflow instance of the given type.

Limitations and requirements:

Each workflow MUST start with a state called I<INITIAL> and MUST have exactly
one action. The factory presets the context value for I<creator> with the
current session user, the inital action SHOULD set the context value I<creator>
to the ID of the (associated) user of this workflow if this differs from the
system user. Note that the creator is afterwards attached as a workflow
attribute and will not be updated if you change the context value later on.

Workflows that fail to complete the I<INITIAL> action are not saved and can not
be continued.

B<Parameters>

=over

=item * C<workflow> I<Str> - workflow name

=item * C<params> I<HashRef> - workflow parameters. Optional, default: {}

=item * C<ui_info> I<Bool> - set to 1 to also return detail informations about
the workflow that can be used in the UI

=back

=cut
command "create_workflow_instance" => {
    workflow => { isa => 'AlphaPunct', required => 1, },
    params   => { isa => 'HashRef', default => sub { {} } },
    ui_info  => { isa => 'Bool', default => 0, },
} => sub {
    my ($self, $params) = @_;
    my $type = $params->workflow;

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    my $workflow = CTX('workflow_factory')->get_factory->create_workflow($type)
        or OpenXPKI::Exception->throw (
            message => "Could not start workflow (type might be unknown)",
            params => { type => $type }
        );
    $workflow->reload_observer;

    ## init creator
    my $id = $workflow->id;
    ##! 2: "New workflow's ID: $id"

    Log::Log4perl::MDC->put('wfid',   $id);
    Log::Log4perl::MDC->put('wftype', $type);

    my $context = $workflow->context;
    my $creator = CTX('session')->data->user;
    $context->param('creator'      => $creator);
    $context->param('creator_role' => CTX('session')->data->role);

    # workflow_id is a virtual key that is added by the Context on init so
    # it does not exist in the fresh context after creation, fixes #442
    # we set it directly to prevent triggering any "on update" methods
    $context->{PARAMS}{'workflow_id'} = $id;

    # This is crucial and must be done before the first execute as otherwise
    # workflow ACLs fails when the first non-initial action is autorun
    $workflow->attrib({ creator => $creator });

    OpenXPKI::Server::Context::setcontext({ workflow_id => $id, force => 1 });

    ##! 16: 'workflow id ' .  $wf_id
    CTX('log')->workflow->info("Workflow instance $id created for $creator (type: '$type')");

    # load the first state and check for the initial action
    my $state = undef;

    my @actions = $workflow->get_current_actions;
    if (scalar @actions != 1) {
        OpenXPKI::Exception->throw (
            message => "Workflow definition does not specify exactly one first activity",
            params => { type => $type }
        );
    }

    my $updated_workflow = $workflow;

    # executing INITAL action: might throw exceptions which are usually caught,
    # handled and rethrown deeper down the hierarchy
    try {
        my $initial_action = shift @actions;

        ##! 8: "initial action: " . $initial_action

        # check the input params
        my $wf_params = $util->validate_input_params($workflow, $initial_action, $params->params);
        ##! 16: ' initial params ' . Dumper  $wf_params

        $context->param($wf_params) if $wf_params;

        ##! 64: Dumper $workflow

        # $updated_workflow is the same as $workflow as long as we do not execute
        # the first workflow step asynchronously: execute_activity(..., async => 1, wait => 1)
        $updated_workflow = $util->execute_activity($workflow, $initial_action);

        # check back for the creator in the context and copy it to the attribute table
        # doh - somebody deleted the creator from the context
        $context->param('creator' => $creator) unless $context->param('creator');
        $workflow->attrib({ creator => $context->param('creator') });
    }
    catch {
        # Safety net: bubble up unknown exceptions.
        # We assume that all OpenXPKI::Exception that may occur have already
        # been handled properly further down the execution chain
        die $_ unless blessed $_ && $_->isa('OpenXPKI::Exception');
    };

    Log::Log4perl::MDC->put('wfid',   undef);
    Log::Log4perl::MDC->put('wftype', undef);

    return ($params->ui_info
        ? $util->get_ui_info(workflow => $updated_workflow)
        : $util->get_workflow_info($updated_workflow)
    );
};

__PACKAGE__->meta->make_immutable;
