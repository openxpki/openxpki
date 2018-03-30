package OpenXPKI::Test::QA::Role::Workflows::InstanceOldApi;
use Moose;
use utf8;

# Core modules
use Test::More;
use Test::Exception;

# Project modules
use OpenXPKI::Server::Context;

=head1 NAME

OpenXPKI::Test::QA::Role::Workflows::InstanceOldApi - represents an instance
of a workflow that can be tested

=head1 METHODS

=cut

################################################################################
# Constructor attributes
#

=head2 new

Constructor: creates a new workflow instance or fetches an existing workflow's state.

Named parameters:

=over

=item * C<oxitest> I<OpenXPKI::Test> - instance of the test object

=item * C<type> I<Str> - new workflow: workflow type (i.e. name)

=item * C<params> I<HashRef> - new workflow: workflow parameters. Default: {}

=item * C<id> I<Str> - existing workflow: ID

=back

=cut

has oxitest => (
    is => 'rw',
    isa => 'OpenXPKI::Test',
);

has type => (
    is => 'rw',
    isa => 'Str',
);

has params => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

has id => (
    is => 'rw',
);

=head2 last_wf_state

Returns the workflow status I<HashRef> as returned by the last execution of the
C<execute_workflow_activity> API command.

=cut
has last_wf_state => (
    is => 'rw',
    isa => 'Any',
    init_arg => undef,
    predicate => 'has_last_wf_state',
);

#
#
#
sub BUILD {
    my $self = shift;

    die "Please specify either 'type' (to create a new workflow) or 'id' (fetch existing one)"
        unless $self->id || $self->type;

    # new workflow
    if ($self->type) {
        my $data = $self->oxitest->api_command(
            create_workflow_instance => {
                WORKFLOW => $self->type,
                PARAMS => $self->params,
            }
        );
        my $id = $data->{WORKFLOW}->{ID} or die explain $data;
        $self->id($id);
        $self->last_wf_state($data->{WORKFLOW}) if $data->{WORKFLOW};
        note "Created workflow #$id (".$self->type.") via old API";
    }
    # existing workflow
    else {
        $self->refresh;
        my $type = $self->last_wf_state->{TYPE} or die explain $self->last_wf_state;
        $self->type($type);
        note "Fetched workflow #".$self->id." ($type) via old API";
    }
}

=head2 refresh

Refreshes the workflow information in this wrapper object by querying the API.

=cut
sub refresh {
    my ($self) = @_;
    my $data = $self->oxitest->api_command(
        get_workflow_info => { ID => $self->id }
    );
    $self->last_wf_state($data->{WORKFLOW}) if $data->{WORKFLOW};
}

=head2 state

Returns the current workflow state. Please use L</refresh> to get current
informations.

=cut
sub state {
    my $self = shift;
    return $self->last_wf_state->{STATE};
}

=head2 start_activity

Executes the API command I<execute_workflow_activity> as a test.

Example:

    $wf->start_activity(
        "csr_ask_client_password",
        { _password => "m4#bDf7m3abd" },
    );

B<Positional Parameters>

=over

=item * C<$activity> I<Str> - workflow activity name

=item * C<$params> I<HashRef> - parameters

=back

=cut
sub start_activity {
    my ($self, $activity, $params) = @_;

    my $result;
    lives_ok {
        $result = $self->oxitest->api_command(
            execute_workflow_activity => {
                ID => $self->id,
                ACTIVITY => $activity,
                PARAMS => $params // {},
            }
        );
        $self->last_wf_state($result->{WORKFLOW}) if $result->{WORKFLOW};
    } "Executing workflow activity $activity";

    return $result;
}

=head2 execute_fails

Executes the API command I<execute_workflow_activity> as a test and expect
it to fail with the given exception.

Example:

    $wf->execute_fails(
        "csr_ask_client_password",
        { _password => "m4#bDf7m3abd" },
        qr/MyException/,
    );

B<Positional Parameters>

=over

=item * C<$activity> I<Str> - workflow activity name

=item * C<$params> I<HashRef> - parameters

=item * C<$failure> I<Regex> - Regular expression that the exceptions is matched agains

=back

=cut
sub execute_fails {
    my ($self, $activity, $params, $failure) = @_;

    my $result;
    throws_ok {
        $self->oxitest->api_command(
            execute_workflow_activity => {
                ID => $self->id,
                ACTIVITY => $activity,
                PARAMS => $params // {},
            }
        );
    } $failure, "Executing workflow activity $activity should fail";
}

=head2 state_is

Checks the state of the workflow (with a L<Test::More> test).

This command only works if the workflow has previously been modified by this
classes methods.

B<Positional Parameters>

=over

=item * C<$expected_state> I<Str> - expected current workflow state

=back

=cut
sub state_is {
    my ($self, $expected_state) = @_;
    is $self->state, $expected_state, "workflow state is '$expected_state'";
}

=head2 change_user

Change the user that is seen by the workflow actions and conditions.

B<Positional Parameters>

=over

=item * C<$user> I<Str> - username

=back

=cut
sub change_user {
    my ($self, $user) = @_;

    $self->oxitest->set_user(OpenXPKI::Server::Context::CTX('session')->data->pki_realm => $user);

    # reset condition cache so e.g. user role checks are re-evaluated
    my $wf = OpenXPKI::Server::Context::CTX('workflow_factory')->get_factory->fetch_workflow($self->type, $self->id);
    $wf->_get_workflow_state->clear_condition_cache;
}

__PACKAGE__->meta->make_immutable;
